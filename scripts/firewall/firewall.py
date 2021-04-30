"""
Main module of Firewall package
"""

import signal
import subprocess
import select
import datetime
import argparse
import yaml
from os import path

is_running = None
log_file = None
poll = None
blocked = {}


def init(auth):
    """Init"""
    global is_running
    global log_file
    global poll

    is_running = True
    if not path.exists("/var/www/" + auth):
        print("\nError!")
        print(f"/var/www/{auth} not found\n")
        is_running = False
        return 1
    log_file = subprocess.Popen(["tail", "-F", "/var/www/" + auth + "/logs/access.log"],
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    poll = select.poll()

    poll.register(log_file.stdout)

    signal.signal(signal.SIGINT, exit_gracefully)
    signal.signal(signal.SIGTERM, exit_gracefully)


def exit_gracefully(arg1, arg2):
    """Exit"""
    global is_running
    is_running = False
    purge_iptables()


def process():
    """Process"""
    global log_file
    global is_running
    global poll
    global blocked

    if poll.poll(1):
        log = log_file.stdout.readline().decode("utf-8").replace('"', " ").split(" ")
        if not is_running:
            return
        ip = log[0]
        date = datetime.datetime.strptime(log[3][1:], '%d/%b/%Y:%H:%M:%S')
        request = log[6]
        request_path = log[7]
        code = int(log[10])
        print(f"{ip} at {date} : {request} -> {request_path} : {code}")

        if request == "POST" and request_path == "/wp-login.php" and code != 302:
            if ip in blocked:
                if (date - blocked[ip][0]).total_seconds() <= 300:
                    blocked[ip][0] = date
                    blocked[ip][1] += 1

                    print(f"\nConnection failed! {ip} - Attempt: {blocked[ip][1]}\n")
                    if blocked[ip][1] >= 5:
                        ban_ip(ip)
                else:
                    blocked[ip] = [date, 1]
                    print(f"\nConnection failed! {ip} - Attempt: {blocked[ip][1]}\n")

            else:
                if (datetime.datetime.now() - date).total_seconds() <= 5:
                    blocked[ip] = [date, 1]
                    print(f"\nConnection failed! New ip detected : {ip} - Attempt: 1\n")

        elif request == "GET" and request_path == "/wp-admin/" and code == 200:
            if ip in blocked:
                del blocked[ip]
                print(f"\nConnection successful! Ip {ip} removed.\n")


def ban_ip(ip):
    """Ban ip"""
    process_result = subprocess.run(f"sudo iptables -A INPUT -s {ip} -j DROP", shell=True)
    if process_result.returncode != 0:
        print("A problem occured to ban ip...")
        print(f"{ip} is not banned!")
    else:
        print(f"{ip} is now banned!")


def purge_iptables():
    """Purge logs"""
    process_result = subprocess.run(f"sudo iptables -F", shell=True)
    if process_result.returncode != 0:
        print("A problem occured to purge iptables...")
        print("\niptables wasn't purged!")
    else:
        print("\niptables purged!")


def main(command_line=None):
    """Main function"""
    global is_running

    parser = argparse.ArgumentParser()
    parser.add_argument("-c", "--config", default="config.yaml", help="Configuration file to load.")
    args = parser.parse_args(command_line)

    # check if file exist
    if not path.exists(args.config):
        print("\nError!")
        print(f"File {args.config} is not found!")
        print(f"Please create it ({args.config}) (.yaml file) and edit it to fill the field 'hostname'.\n")
        print("Example:\nhostname: \"MyName\"\n")
        return 1

    # check if file is an YAML file
    if not args.config.lower().endswith(".yaml"):
        print("\nError!")
        print("Selected file isn't a YAML file!\n")
        return 1

    # read the file
    with open(args.config, "r") as s:
        y = yaml.safe_load(s)
        try:
            hostname = y["hostname"]
        except:
            hostname = None
        finally:
            # check hostname
            if hostname is None or len(hostname) == 0:
                print("\nError!")
                print(f"Field 'hostname' has no value in {args.config} file!\n")
                return 1

    init(hostname)
    while is_running:
        process()
    return 0


if __name__ == '__main__':
    main()

"""
Main module of Firewall package
"""

import signal
import subprocess
import select
import datetime

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
        path = log[7]
        code = int(log[10])
        print(f"{ip} at {date} : {request} -> {path} : {code}\n")

        if request == "POST" and path == "/wp-login.php" and code != 302:
            if ip in blocked:
                if (date - blocked[ip][0]).total_seconds() <= 300:
                    blocked[ip][0] = date
                    blocked[ip][1] += 1
                    print(f"{ip} try connection: {blocked[ip][1]}\n")
                    if blocked[ip][1] == 5:
                        ban_ip(ip)
                else:
                    blocked[ip] = [date, 1]
                    print(f"Ip {ip} reseted to 1.\n")
            else:
                if (datetime.datetime.now() - date).total_seconds() <= 5:
                    blocked[ip] = [date, 1]
                    print(f"New ip detected : {ip}\n")

        elif request == "GET" and "/wp-admin.php" in path and code == 302:
            if ip in blocked:
                del blocked[ip]
                print(f"Ip {ip} removed.\n")


def ban_ip(ip):
    """Ban ip"""
    print(f"{ip} is now banned!")
    subprocess.call(f"iptables -A INPUT -s {ip} -j DROP", shell=True)


def purge_iptables():
    """Purge logs"""
    print("\niptables purged!")
    subprocess.call(f"iptables -F", shell=True)


def main():
    """Main function"""
    init("test")
    while is_running:
        process()


if __name__ == '__main__':
    main()

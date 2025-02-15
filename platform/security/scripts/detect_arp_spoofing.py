import os
import logging
from scapy.all import ARP, sniff

# Configure logging
log_file = os.getenv("LOG_FILE", "/var/log/soa_observability/arp_spoofing.log")
logging.basicConfig(filename=log_file, level=logging.WARNING, format='%(asctime)s - %(message)s')

# IP-MAC mappings
ip_mac_dict = {}


def arp_spoof_detector(packet):
    if ARP in packet and packet[ARP].op in (1, 2):  # who-has or is-at
        source_ip = packet[ARP].psrc
        source_mac = packet[ARP].hwsrc

        if source_ip in ip_mac_dict and ip_mac_dict[source_ip] != source_mac:
            logging.warning("[WARNING] ARP Spoofing Detected!")
            logging.warning("Attacker MAC: %s", source_mac)
            logging.warning("Attacker IP: %s", source_ip)
            logging.warning("Genuine MAC: %s", ip_mac_dict[source_ip])
            logging.warning("Genuine IP: %s", source_ip)
            logging.warning("--------------------------------------")

        ip_mac_dict[source_ip] = source_mac


if __name__ == "__main__":
    sniff(prn=arp_spoof_detector, filter="arp", store=0)

import pytest

from unifi.api_client import UnifiController
from unifi.io import export_csv, export_json

SITE_NAME = "default"


@pytest.fixture
def unifi_controller():
    controller = UnifiController(
        controller_url="https://<CONTROLLER_IP_OR_HOSTNAME>", # Use :8443 for dedicated controller
        username="<LOCAL_ADMIN_USER>",
        password="<PASSWORD>",
        is_udm_pro=True,
        verify_ssl=False
    )
    return controller


def test_client_initialization():
    controller = UnifiController(
        controller_url="https://<CONTROLLER_IP_OR_HOSTNAME>", # Use :8443 for dedicated controller
        username="<LOCAL_ADMIN_USER>",
        password="<PASSWORD>",
        is_udm_pro=True,
        verify_ssl=False
    )
    assert controller is not None


def test_get_unifi_device(unifi_controller):
    try:
        devices = unifi_controller.get_unifi_site_device(site_name=SITE_NAME, detailed=True)

        for device in devices:
            print(f"- {device.name} ({device.model_name}): {device.ip} / {device.mac}")
            if device.lldp_info:
                print(f"  LLDP: {len(device.lldp_info)} neighbors")

    except Exception as e:
        print(f"Error fetching devices for site '{SITE_NAME}': {e}")

# Other available methods:
# sites = controller.get_unifi_site()
# clients = controller.get_clients(site_name)
# wlans = controller.get_wlan_conf(site_name)
# alarms = controller.get_alarms(site_name)
# events = controller.get_events(site_name)
# rogue_aps = controller.get_rogue_aps(site_name)
# networks = controller.get_network_conf(site_name)
# report = controller.devices_report(site_names=['site1', 'site2'])

def test_export_data(unifi_controller):

    devices = unifi_controller.get_unifi_site_device(site_name=SITE_NAME, detailed=True)
    if devices:
        export_csv(devices, "devices.csv")
        export_json(devices, "devices.json")

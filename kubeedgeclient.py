import os
import psutil
import sys
import time
import json
import RPi.GPIO as GPIO

import paho.mqtt.client as mqtt

device_id = os.environ.get('DEVICE_ID', 'devicen')

def get_timestamp():
    return int(round(time.time() * 1000))

def init_gpio(gpio):
    GPIO.setmode(GPIO.BCM)
    GPIO.setup(gpio,GPIO.OUT)
    GPIO.output(18,GPIO.HIGH)	# off by default

def led_on(gpio):
    GPIO.output(18,GPIO.LOW)

def led_off(gpio):
    GPIO.output(18,GPIO.HIGH)

def on_connect(client, userdata, flags, rc):
    print('\n%s' % mqtt.connack_string(rc))
    if rc != 0:
        client.bad_connection_flag=True
    else:
        client.connected_flag=True

# Callback on specific matched topic(s)
def chk_twin(client, userdata, msg):
    propertyName = 'power-status'
    twin = json.loads(msg.payload)
    print('   Got:', json.dumps(twin))
    if propertyName in twin['twin']:
        expected = twin['twin'][propertyName]['expected']['value']
        if 'actual' in twin['twin'][propertyName]:
            actual = twin['twin'][propertyName]['actual']['value']
        else:
            actual = "unknown"
        print('Twin states: expected {}, actual {}'.format(expected, actual))
        if expected != actual:
            print("Syncing state to an expected one...")
            updated_time = get_timestamp()
            updated = {'event_id': '','timestamp': updated_time, 'twin': {propertyName: {'actual': {'value': expected, 'metadata':{'timestamp': updated_time}}}}}
            updated_state = json.dumps(updated)
            print('Update:', updated_state)
            if expected == 'ON':
                led_on(18)
            else:
                led_off(18)
            client.publish('$hw/events/device/' + device_id + '/twin/update', updated_state)

# The callback for receiving message on subscribed topic.
def on_message(client, userdata, message):
    print(message.topic+ " " + str(message.payload))

def publish_cpu_usage(client):
    current_usage = psutil.cpu_percent()
    print('CPU %: ', current_usage)
    updated_time = get_timestamp()
    client.publish('$hw/events/device/' + device_id + '/state/update', '{"cpu-usage":"' + str(current_usage) + '"}')
    json_body = '{"event_id": "", "timestamp": ' + str(updated_time) + ', "twin" : {"cpu-usage": {"actual": {"value": "' + str(current_usage) + '"}, "metadata": {"type" : "Updated"}}}}'
#    print(json.loads(json_body))
    client.publish('$hw/events/device/' + device_id + '/twin/update', json_body)

device_token = os.environ.get('TOKEN', '17ANBw00OHGWGoRxAIIA')
broker_ip = os.environ.get('BROKER_IP', '10.0.100.5')
broker_port = os.environ.get('BROKER_PORT', '1883')

client = mqtt.Client(client_id="eventbus", protocol=mqtt.MQTTv311)
#client.username_pw_set(device_token)
client.on_connect = on_connect
client.on_message = on_message
client.message_callback_add('$hw/events/device/' + device_id + '/twin/get/result', chk_twin)

client.connected_flag=False
client.bad_connection_flag=False

client.loop_start()
print('Connecting to {}:{}'.format(broker_ip, broker_port))
client.connect(broker_ip, int(broker_port), keepalive=30)

while not client.connected_flag and not client.bad_connection_flag:
    sys.stdout.write('.')
    time.sleep(1)

if client.bad_connection_flag:
    client.loop_stop()
    sys.exit()

init_gpio(18)

rc = client.subscribe('$hw/events/device/' + device_id + '/twin/get/result', qos=0)
print('subscribe', rc)
while True:
    rc = client.publish('$hw/events/device/' + device_id + '/state/update', '{"state":"online"}')
    time.sleep(1)
    rc = client.publish('$hw/events/device/' + device_id + '/twin/get', '{"state":"online"}')
#    publish_cpu_usage(client)
    time.sleep(5)

client.loop_forever()

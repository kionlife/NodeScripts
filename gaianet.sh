#!/bin/bash

# Python script filename
PYTHON_SCRIPT_NAME="request_script.py"
VENV_DIR="venv"

# Check if script is running with superuser privileges
if [ "$EUID" -ne 0 ]; then
    echo "Please run the script with superuser privileges (sudo)."
    exit 1
fi

# Check if Python is installed, install if not
if ! command -v python3 &> /dev/null; then
    echo "Python3 not found, installing..."
    apt update
    apt install python3 -y
else
    echo "Python3 is already installed"
fi

# Install python3-venv if not installed
if ! dpkg -s python3-venv &> /dev/null; then
    echo "Installing python3-venv..."
    apt install python3-venv -y
else
    echo "python3-venv is already installed"
fi

# Check if pip is installed, install if not
if ! command -v pip3 &> /dev/null; then
    echo "pip3 not found, installing..."
    apt update
    apt install python3-pip -y
else
    echo "pip3 is already installed"
fi

# Install virtualenv if not installed
if ! pip3 show virtualenv &> /dev/null; then
    echo "Installing virtualenv..."
    pip3 install virtualenv
else
    echo "virtualenv is already installed"
fi

# Create virtual environment
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv $VENV_DIR
fi

# Activate virtual environment
source $VENV_DIR/bin/activate

# Install requests and faker libraries if not installed
if ! pip3 show requests &> /dev/null; then
    echo "Requests library not found, installing..."
    pip3 install requests
else
    echo "Requests library is already installed"
fi

if ! pip3 show faker &> /dev/null; then
    echo "Faker library not found, installing..."
    pip3 install faker
else
    echo "Faker library is already installed"
fi

# Create Python script
echo "Creating Python script..."
cat << EOF > $PYTHON_SCRIPT_NAME
import requests
import json
import time
import logging

# ------------------------------------------------------------------------------------------
'''
Just change the link to your node, then run.
It will automatically conduct a dialogue with a 10-second delay between messages.
'''
# ------------------------------------------------------------------------------------------

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(message)s")

gaianetLink = 'https://movie.gaia.domains/v1/chat/completions'

GREEN = "\033[32m"
RESET = "\033[0m"

class DualAPIClient:
    def __init__(self, gpt_config, custom_config):
        self.gpt_config = gpt_config
        self.custom_config = custom_config
        self.previous_question = None  # Variable to store previous question

    def _send_request(self, config):
        try:
            response = requests.post(config['url'], headers=config['headers'], data=json.dumps(config['data']))
            if response.status_code == 200:
                return response.json()
            else:
                return {
                    "error": response.status_code,
                    "message": response.text
                }
        except requests.exceptions.RequestException as e:
            return {
                "error": "network_error",
                "message": str(e)
            }

    def send_gpt_request(self, user_message):
        if self.previous_question:
            usr_message = f"{user_message} + 'your previous response: {self.previous_question}'"
        else:
            usr_message = user_message

        self.gpt_config['data']['messages'][1]['content'] = usr_message
        response = self._send_request(self.gpt_config)

        if "error" not in response:
            self.previous_question = self.extract_answer(response)

        return response

    def send_custom_request(self, user_message):
        self.custom_config['data']['messages'][1]['content'] = user_message
        return self._send_request(self.custom_config)

    def extract_answer(self, response):
        if "error" in response:
            return f"Error: {response['error']} - {response['message']}"
        return response.get('choices', [{}])[0].get('message', {}).get('content', '')


gpt_config = {
    'url': f'https://movie.gaia.domains/v1/chat/completions',
    'headers': {
        'accept': 'application/json',
        'Content-Type': 'application/json'
    },
    'data': {
        "messages": [
            {"role": "system", "content": 'You are a movie expert. Answer with one short phrase about movies.'},
            {"role": "user", "content": ""}
        ]
    }
}

gaianet_config = {
    'url': f'https://movie.gaia.domains/v1/chat/completions',
    'headers': {
        'accept': 'application/json',
        'Content-Type': 'application/json'
    },
    'data': {
        "messages": [
            {"role": "system", "content": "You are a movie critic. Respond with one interesting movie fact or suggestion."},
            {"role": "user", "content": ""}
        ]
    }
}

client = DualAPIClient(gpt_config, gaianet_config)

initial_question = "Let's discuss classic movies from the Golden Age of Hollywood!"
gpt_response = client.send_gpt_request(initial_question)

while True:
    print(f'\n{GREEN}' + time.strftime("%Y-%m-%d %H:%M:%S", time.localtime()) + f" [GPT Question]:{RESET}")

    if "error" in gpt_response:
        logging.error(f"GPT Request Error {gpt_response['error']}: {gpt_response['message']}")
        gpt_answer = "Error occurred. Please retry."
    else:
        gpt_answer = client.extract_answer(gpt_response).replace('\n', ' ')
        print(gpt_answer)

    custom_response = client.send_custom_request(gpt_answer + ' Suggest another movie topic to discuss')

    print(f'\n{GREEN}' + time.strftime("%Y-%m-%d %H:%M:%S", time.localtime()) + f" [GaiaNet Response]:{RESET}")

    if "error" in custom_response:
        logging.error(f"GaiaNet Request Error {custom_response['error']}: {custom_response['message']}")
        custom_answer = "Error occurred. Please retry."
    else:
        custom_answer = client.extract_answer(custom_response).replace('\n', ' ')
        print(custom_answer)

    gpt_response = client.send_gpt_request(custom_answer)
    time.sleep(1)

EOF

echo "Python script created. You can run it with the command: python3 $PYTHON_SCRIPT_NAME"

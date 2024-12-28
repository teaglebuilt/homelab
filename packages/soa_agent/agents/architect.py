import logging
import os

from collections import defaultdict
from dotenv import load_dotenv
from soa_agent.constants import IMAGE_FORMATS
import lib.stdout_utils as stdout


logging.basicConfig(level=logging.INFO, format="%(message)s")


MODEL_ID = ""
RECURSION_LIMIT = 5
SYSTEM_PROMPT = """
You are an AWS Solutions Architect who can answer questions about an architecture diagram.
"""


class ArchitectureChat:
    def __init__(self):
        self.system_prompt = [{"text": SYSTEM_PROMPT}]
        self.client = None

    def run(self):
        stdout.header()

        architecture_diagram_file = self._get_user_input(
            "What is the name of the file you want to chat with? File must be located in the demo/ directory."
        )
        user_input = self._get_user_input()

        while user_input is not None:
            if architecture_diagram_file:
                _, file_extension = os.path.splitext(architecture_diagram_file)
                file_extension = file_extension.lstrip('.').lower()

                if file_extension in IMAGE_FORMATS:
                     with open(architecture_diagram_file, "rb") as image_file:
                        self.build_message_to_client(image_file, user_input)
                else:
                    logging.warning(f"Unsupported file format: {file_extension}")
            else:
                self.build_message_to_client(user_input)

    def _build_message_to_client(self, user_input, image_file=None):
        payload = {
            "role": "user",
            "content": defaultdict(list),
        }
        breakpoint()

    def _send_conversation_to_ai_client(self, conversation):
        stdout.call_to_ai_client(conversation)

    def _process_model_response(
        self, model_response, conversation, recursion_limit=RECURSION_LIMIT
    ):
        if recursion_limit <= 0:
            # Stop the process, the number of recursive calls could indicate an infinite loop
            logging.warning(
                "Warning: Maximum number of recursions reached. Stopping the process."
            )
            exit(1)

        message = model_response["output"]["message"]
        conversation.append(message)

        if model_response["stopReason"] == "end_turn":
            # If the stop reason is "end_turn", print the model's response text, and finish the process
            stdout.model_response(message["content"][0]["text"])
            return

    @staticmethod
    def _get_user_input(prompt="Your query"):
        stdout.separator()
        user_input = input(f"{prompt} (x to exit): ")

        if user_input == "":
            prompt = "Please enter your query"
            return ArchitectureChat._get_user_input(prompt)

        if user_input == "":
            prompt = "Please enter your query"
            return ArchitectureChat._get_user_input(prompt)
        elif user_input.lower() == "x":
            return None
        else:
            return user_input


if __name__ == "__main__":
    architecture_chat_demo = ArchitectureChat()
    architecture_chat_demo.run()

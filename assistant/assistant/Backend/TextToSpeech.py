import pygame
import random
import asyncio
import edge_tts
import os
from dotenv import dotenv_values

# Load environment variables
env_vars = dotenv_values(".env")
AssistantVoice = env_vars.get("AssistantVoice")

# Async function to convert text to audio file
async def TextToAudioFile(text: str) -> None:
    file_path = r"Data\speech.mp3"
    if os.path.exists(file_path):
        os.remove(file_path)
    communicate = edge_tts.Communicate(text, AssistantVoice, pitch="+5Hz", rate="+13%")
    await communicate.save(file_path)

# Function for text-to-speech using pygame
def TTS(Text: str, func=lambda r=None: True):
    try:
        asyncio.run(TextToAudioFile(Text))
        pygame.mixer.init()
        pygame.mixer.music.load(r"Data\speech.mp3")
        pygame.mixer.music.play()

        while pygame.mixer.music.get_busy():
            if not func():
                break
            pygame.time.Clock().tick(10)
        return True
    except Exception as e:
        print(f"Error in TTS function: {e}")
    finally:
        try:
            func(False)
            pygame.mixer.music.stop()
            pygame.mixer.quit()
        except Exception as final_e:
            print(f"Error during cleanup: {final_e}")

# Text-to-speech function with additional responses
def TextToSpeech(Text: str, func=lambda r=None: True):
    Data = str(Text).split(".")
    responses = [
        "The rest of the result has been printed to the chat screen, kindly check it out sir.",
        "The rest of the text is now on the chat screen, sir, please check it.",
        "You can see the rest of the text on the chat screen, sir.",
        "The remaining part of the text is now on the chat screen, sir.",
        "Sir, you'll find more text on the chat screen for you to see.",
    ]
    TTS(Text, func)
if __name__ == "__main__":
    while True:
        TextToSpeech(input("Enter The Text: "))

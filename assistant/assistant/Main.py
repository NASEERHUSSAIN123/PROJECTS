from Frontend.GUI import (
    GraphicalUserInterface,
    SetAssistantStatus,
    ShowTextToScreen,
    TempDirectoryPath,
    SetMicrophoneStatus,
    AnswerModifier,
    QueryModifier,
    GetMicrophoneStatus
)
from Backend.Model import FirstLayerDMM
from Backend.RealtimeSearchEngine import RealtimeSearchEngine
from Backend.Automation import Automation
from Backend.SpeechToText import SpeechRecognition
from Backend.Chatbot import ChatBot
from Backend.TextToSpeech import TextToSpeech
from dotenv import dotenv_values
from asyncio import run
import subprocess
import threading
import json
import os

# Load environment variables
env_vars = dotenv_values(".env")
Username = env_vars.get("Username", "User")
Assistantname = env_vars.get("Assistantname", "Assistant")

# Default chat if none exists
DefaultMessage = f'''{Username}:Hello {Assistantname},How are you?
{Assistantname}:Welcome {Username}. I am doing well, How may I help you?'''

image_processes = []
Functions = ["open", "close", "play", "system", "content", "google search", "youtube search"]

def ShowDefaultChatIfNoChats():
    try:
        with open(r'Data\ChatLog.json', "r", encoding='utf-8') as file:
            if len(file.read()) < 5:
                with open(TempDirectoryPath('Database.data'), "w", encoding='utf-8') as f:
                    f.write("")
                with open(TempDirectoryPath('Responses.data'), "w", encoding='utf-8') as f:
                    f.write(DefaultMessage)
    except FileNotFoundError:
        os.makedirs("Data", exist_ok=True)
        with open(r'Data\ChatLog.json', "w", encoding='utf-8') as f:
            json.dump([], f)
        ShowDefaultChatIfNoChats()

def ReadChatLogJson():
    with open(r'Data\ChatLog.json', 'r', encoding='utf-8') as file:
        return json.load(file)

def ChatLogIntegration():
    json_data = ReadChatLogJson()
    formatted_chatlog = ""
    for entry in json_data:
        if entry["role"] == "user":
            formatted_chatlog += f"User: {entry['content']}\n"
        elif entry["role"] == "assistant":
            formatted_chatlog += f"Assistant: {entry['content']}\n"
    formatted_chatlog = formatted_chatlog.replace("User", Username)
    formatted_chatlog = formatted_chatlog.replace("Assistant", Assistantname)
    with open(TempDirectoryPath('Database.data'), 'w', encoding='utf-8') as file:
        file.write(AnswerModifier(formatted_chatlog))

def ShowChatsOnGUI():
    with open(TempDirectoryPath('Database.data'), 'r', encoding='utf-8') as file:
        data = file.read()
    if len(data) > 0:
        with open(TempDirectoryPath('Responses.data'), "w", encoding='utf-8') as file:
            file.write('\n'.join(data.split('\n')))

def InitialExecution():
    SetMicrophoneStatus("False")
    ShowTextToScreen("")
    ShowDefaultChatIfNoChats()
    ChatLogIntegration()
    ShowChatsOnGUI()

InitialExecution()

def MainExecution():
    TaskExecution = False
    ImageExecution = False
    ImageGenerationQuery = ""

    SetAssistantStatus("Listening...")
    Query = SpeechRecognition()
    ShowTextToScreen(f"{Username}: {Query}")
    SetAssistantStatus("Thinking...")

    Decision = FirstLayerDMM(Query)
    print(f"\nDecision: {Decision}\n")

    # Check for image generation command
    for query in Decision:
        if "generate image" in query.lower() or query.lower().startswith("generate"):
            ImageGenerationQuery = query
            ImageExecution = True

    # Check for automation task
    for query in Decision:
        if not TaskExecution and any(query.startswith(func) for func in Functions):
            run(Automation(list(Decision)))
            TaskExecution = True

    # Handle image generation subprocess
    if ImageExecution:
        image_file_path = os.path.join("Frontend", "Files", "ImageGeneration.data")
        os.makedirs(os.path.dirname(image_file_path), exist_ok=True)

        with open(image_file_path, "w", encoding='utf-8') as file:
            file.write(f"{ImageGenerationQuery},True")
        print(f"[LOG] Written to ImageGeneration.data: {ImageGenerationQuery},True")

        try:
            print("[LOG] Launching Backend/ImageGeneration.py subprocess...")
            p1 = subprocess.Popen(
                ['python', os.path.join('Backend', 'ImageGeneration.py')],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                stdin=subprocess.PIPE,
                shell=False
            )
            image_processes.append(p1)
            print("[LOG] ImageGeneration subprocess started.")
        except Exception as e:
            print(f"[ERROR] Could not start ImageGeneration.py: {e}")

    G = any(i.startswith("general") for i in Decision)
    R = any(i.startswith("realtime") for i in Decision)

    Message_query = " and ".join(
        " ".join(i.split()[1:]) for i in Decision if i.startswith("general") or i.startswith("realtime")
    )

    if G and R or R:
        SetAssistantStatus("Searching....")
        Answer = RealtimeSearchEngine(QueryModifier(Message_query))
        ShowTextToScreen(f"{Assistantname}: {Answer}")
        SetAssistantStatus("Answering....")
        TextToSpeech(Answer)
        return True
    else:
        for query in Decision:
            if "general" in query:
                SetAssistantStatus("Thinking....")
                QueryFinal = query.replace("general ", "")
                Answer = ChatBot(QueryModifier(QueryFinal))
                ShowTextToScreen(f"{Assistantname}: {Answer}")
                SetAssistantStatus("Answering....")
                TextToSpeech(Answer)
                return True
            elif "realtime" in query:
                SetAssistantStatus("Searching....")
                QueryFinal = query.replace("realtime ", "")
                Answer = RealtimeSearchEngine(QueryModifier(QueryFinal))
                ShowTextToScreen(f"{Assistantname}: {Answer}")
                SetAssistantStatus("Answering....")
                TextToSpeech(Answer)
                return True
            elif "exit" in query:
                QueryFinal = "Okay, Bye!"
                Answer = ChatBot(QueryModifier(QueryFinal))
                ShowTextToScreen(f"{Assistantname}: {Answer}")
                SetAssistantStatus("Answering...")
                TextToSpeech(Answer)
                os._exit(1)

def FirstThread():
    while True:
        if GetMicrophoneStatus() == "True":
            MainExecution()

def SecondThread():
    GraphicalUserInterface()

if __name__ == "__main__":
    thread1 = threading.Thread(target=FirstThread, daemon=True)
    thread1.start()
    SecondThread()

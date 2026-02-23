from AppOpener import close, open as appopen
from webbrowser import open as webopen
from pywhatkit import search, playonyt
from dotenv import dotenv_values
from bs4 import BeautifulSoup
from rich import print
from groq import Groq
import webbrowser
import subprocess
import requests
import keyboard
import asyncio
import os
env_vars = dotenv_values(".env")
GroqAPIKey = env_vars.get("GroqAPIKey")
classes = [
    "zCubfw", "hgKElc", "LTKOO sY7ric", "Z0LcW", "gsrt vk_bk FzWSb", "pclqee",
    "tw-Data-text tw-text-small tw-ta", "IZ6rdc", "O5uR6d LTKOO", "vlzY6d",
    "webanswers-webanswers_table_webanswers-table", "dDoNo ikb4Bb gsrt",
    "sXLaOe", "LWkfKe", "VQF4g", "qv3Wpe", "kno-rdesc", "SPZz6b"
]
user_agent = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/100.0.4896.75 Safari/537.36"
)
client = Groq(api_key=GroqAPIKey)
professional_responses = [
    "Your satisfaction is my top priority; Feel free to reach out if there's anything else I can help you with.",
    "I'm at your service for any additional questions or support you may need—do not hesitate to ask."
]
messages = []
SystemChatBot = [{
    "role": "system",
    "content": f"Hello, I am {os.getenv('USERNAME', 'User')}, You are a BTech student"
}]
def GoogleSearch(topic):
    search(topic)  # Fixed case
    return True
def Content(topic):
    def OpenNotepad(file_path):
        default_text_editor = 'notepad.exe'
        subprocess.Popen([default_text_editor, file_path])
    def ContentWriterAI(prompt):
        messages.append({"role": "user", "content": prompt})
        completion = client.chat.completions.create(
            model="llama3-70b-8192",
            messages=SystemChatBot + messages,
            max_tokens=2048,
            temperature=0.7,
            top_p=1,
            stream=True,
            stop=None
        )
        answer = ""
        for chunk in completion:
            if chunk.choices[0].delta.content:
                answer += chunk.choices[0].delta.content
        answer = answer.replace("</s>", "")
        messages.append({"role": "assistant", "content": answer})
        return answer
    topic = topic.replace("Content ", "")
    content_by_ai = ContentWriterAI(topic)
    file_path = rf"Data\{topic.lower().replace(' ', '')}.txt"
    with open(file_path, "w", encoding="utf-8") as file:
        file.write(content_by_ai)
    OpenNotepad(file_path)
    return True
def YoutubeSearch(Topic):
    Url4Search=f"https://www.youtube.com/results?search_query={Topic}"
    webbrowser.open(Url4Search)
    return True
def PlayYoutube(query):
    playonyt(query)
    return True
def OpenApp(app,sess=requests.session()):
    try:
        appopen(app,match_closest=True,output=True,throw_error=True)
        return True
    except:
        url=f"https:///www.google.com/search?q={app}"
        webbrowser.open(url)
def CloseApp(app):
    if "chrome" in app:
        pass
    else:
        try:
            close(app,match_closest=True,output=True,throw_error=True)
            return True
        except:
            return False
def System(command):
    def mute():
        keyboard.press_and_release("volume mute")
    def unmute():
        keyboard.press_and_release("volume mute")
    def volume_up():
        keyboard.press_and_release("volume up")
    def volume_down():
        keyboard.press_and_release("volume down")
    if command=="mute":
        mute()
    elif command=="unmute":
        unmute()
    elif command=="volume up":
        volume_up()
    elif command=="volume down":
        volume_down()
    return True
async def TranslateAndExecute(commands: list[str]):
    funcs=[]
    for command in commands:
        if command.startswith("open "):
            if "open it" in command:
                pass
            if "open file"==command:
                pass
            else:
                fun=asyncio.to_thread(OpenApp,command.removeprefix("open "))
                funcs.append(fun)
        elif command.startswith("general "):
            pass
        elif command.startswith("realtime "):
            pass
        elif command.startswith("close "):
            fun=asyncio.to_thread(CloseApp,command.removeprefix("close "))
            funcs.append(fun)
        elif command.startswith("play "):
            fun=asyncio.to_thread(PlayYoutube,command.removeprefix("play "))
            funcs.append(fun)
        elif command.startswith("content "):
            fun=asyncio.to_thread(Content,command.removeprefix("content "))
            funcs.append(fun)
        elif command.startswith("google search "):
            fun=asyncio.to_thread(GoogleSearch,command.removeprefix("google search "))
            funcs.append(fun)
        elif command.startswith("youtube search "):
            fun=asyncio.to_thread(YoutubeSearch,command.removeprefix("youtube search "))
            funcs.append(fun)
        elif command.startswith("system "):
            fun=asyncio.to_thread(Content,command.removeprefix("system "))
            funcs.append(fun)
        else:
            print(f"No Function found, for {command}")
    results=await asyncio.gather(*funcs)
    for result in results:
        if isinstance(result,str):
            yield result
        else:
            yield result
async def Automation(commands: list[str]):
    async for result in TranslateAndExecute(commands):
        pass
    return True
if __name__=="__main__":
    asyncio.run(Automation(["open facebook","open xampp control panel","open telegram","play AI models","content on AI"]))
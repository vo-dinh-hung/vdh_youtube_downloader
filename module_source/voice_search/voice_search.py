import speech_recognition as sr
import sys
import io
from accessible_output3.outputs.auto import Auto
speak = Auto().speak

if sys.stdout is not None:
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8')
    elif hasattr(sys.stdout, 'buffer'):
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
if sys.stderr is not None:
    if hasattr(sys.stderr, 'reconfigure'):
        sys.stderr.reconfigure(encoding='utf-8')
    elif hasattr(sys.stderr, 'buffer'):
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

def main():
    target_language = sys.argv[1] if len(sys.argv) > 1 else "vi-VN"

    r = sr.Recognizer()
    r.pause_threshold = 0.6  # Giảm xuống để nhận diện nhanh hơn sau khi nói xong
    r.operation_timeout = 15  # Thời gian tối đa chờ Google phản hồi
    
    try:
        with sr.Microphone() as source:
            r.adjust_for_ambient_noise(source, duration=0.5) # Giảm thời gian hiệu chỉnh môi trường
            speak("Listening", interrupt=True)
            try:
                audio = r.listen(source, timeout=5, phrase_time_limit=10)
            except sr.WaitTimeoutError:
                speak("No speech detected, please try again.", interrupt=True)
                return

        speak("Processing", interrupt=True)
        text = r.recognize_google(audio, language=target_language)
        print(text.strip(), flush=True)
        speak("Finished", interrupt=True)

    except sr.UnknownValueError:
        speak("Could not understand audio, please try again.", interrupt=True)
    except sr.RequestError as e:
        speak("Network error, please check your internet connection.", interrupt=True)
        print(f"Request Error: {e}", file=sys.stderr)
    except Exception as e:
        speak("An unknown error occurred.", interrupt=True)
        import traceback
        with open("error.log", "a", encoding="utf-8") as f:
            traceback.print_exc(file=f)
        print(f"Error: {e}", file=sys.stderr)

if __name__ == "__main__":
    main()
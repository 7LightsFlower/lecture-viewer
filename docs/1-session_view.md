# Meeting sesion view

Create a meeting view screen.

After scan the QR code, show a modal asking users if they want to join
the meeting. Extract the meeting_name (the last part of the link split by /)
For example, https://lectureviewer.app.link/Il4A2yzQrPb?link_record=lt2srv.iar.kit.edu/mobile/session/tkq1221114001-lecture -> meeting_name = tkq1221114001-lecture
Show the name on the modal.

## Meeting view detail
After navigate to the meeting detail,
connect the websocket at wss://<base_url>/ws/lecture-session?sessionID=<meeting_name>

where the base_url is the value depends on production or testing environment.

There are many json messages returned via websocket, below are some of them and their corresponding logics:

### message info (not that there can be other message info with different schema)
{
    "message": "connected",
    "status": 200,
    "data": {
        "computedSenders": {
            "summarizer:0_mult8": {
                "language": "Transcript",
                "type": "summarizer",
                "percent": 0,
                "langCode": "mult8",
                "original": "summarizer:0_mult8"
            },
            "textstructurer:0_mult8": {
                "language": "Transcript",
                "type": "textstructurer",
                "percent": 0,
                "langCode": "mult8",
                "original": "textstructurer:0_mult8"
            },
            "postproduction:50_mult8": {
                "language": "Transcript",
                "type": "postproduction",
                "percent": 50,
                "langCode": "mult8",
                "original": "postproduction:50_mult8"
            },
            "asr:0": {
                "language": "Transcript",
                "type": "asr",
                "percent": 0,
                "original": "asr:0"
            },
            "postproduction:90_mult8": {
                "language": "Transcript",
                "type": "postproduction",
                "percent": 90,
                "langCode": "mult8",
                "original": "postproduction:90_mult8"
            },
            "postproduction:70_mult8": {
                "language": "Transcript",
                "type": "postproduction",
                "percent": 70,
                "langCode": "mult8",
                "original": "postproduction:70_mult8"
            },
            "textstructurer:0_en": {
                "language": "English",
                "type": "textstructurer",
                "percent": 0,
                "langCode": "en",
                "original": "textstructurer:0_en"
            },
            "mt:0": {
                "language": "English",
                "type": "mt",
                "percent": 0,
                "original": "mt:0"
            },
            "summarizer:0_en": {
                "language": "English",
                "type": "summarizer",
                "percent": 0,
                "langCode": "en",
                "original": "summarizer:0_en"
            },
            "postproduction:70_en": {
                "language": "English",
                "type": "postproduction",
                "percent": 70,
                "langCode": "en",
                "original": "postproduction:70_en"
            },
            "postproduction:90_en": {
                "language": "English",
                "type": "postproduction",
                "percent": 90,
                "langCode": "en",
                "original": "postproduction:90_en"
            },
            "postproduction:50_en": {
                "language": "English",
                "type": "postproduction",
                "percent": 50,
                "langCode": "en",
                "original": "postproduction:50_en"
            },
            "textstructurer:0_de": {
                "language": "German",
                "type": "textstructurer",
                "percent": 0,
                "langCode": "de",
                "original": "textstructurer:0_de"
            },
            "postproduction:50_de": {
                "language": "German",
                "type": "postproduction",
                "percent": 50,
                "langCode": "de",
                "original": "postproduction:50_de"
            },
            "summarizer:0_de": {
                "language": "German",
                "type": "summarizer",
                "percent": 0,
                "langCode": "de",
                "original": "summarizer:0_de"
            },
            "mt:1": {
                "language": "German",
                "type": "mt",
                "percent": 0,
                "original": "mt:1"
            },
            "postproduction:70_de": {
                "language": "German",
                "type": "postproduction",
                "percent": 70,
                "langCode": "de",
                "original": "postproduction:70_de"
            },
            "mt:2": {
                "language": "Greek",
                "type": "mt",
                "percent": 0,
                "original": "mt:2"
            },
            "postproduction:90_de": {
                "language": "German",
                "type": "postproduction",
                "percent": 90,
                "langCode": "de",
                "original": "postproduction:90_de"
            },
            "textstructurer:0_el": {
                "language": "Greek",
                "type": "textstructurer",
                "percent": 0,
                "langCode": "el",
                "original": "textstructurer:0_el"
            },
            "postproduction:70_el": {
                "language": "Greek",
                "type": "postproduction",
                "percent": 70,
                "langCode": "el",
                "original": "postproduction:70_el"
            },
            "summarizer:0_el": {
                "language": "Greek",
                "type": "summarizer",
                "percent": 0,
                "langCode": "el",
                "original": "summarizer:0_el"
            },
            "postproduction:50_el": {
                "language": "Greek",
                "type": "postproduction",
                "percent": 50,
                "langCode": "el",
                "original": "postproduction:50_el"
            },
            "postproduction:90_el": {
                "language": "Greek",
                "type": "postproduction",
                "percent": 90,
                "langCode": "el",
                "original": "postproduction:90_el"
            },
            "textstructurer:0_it": {
                "language": "Italian",
                "type": "textstructurer",
                "percent": 0,
                "langCode": "it",
                "original": "textstructurer:0_it"
            },
            "summarizer:0_it": {
                "language": "Italian",
                "type": "summarizer",
                "percent": 0,
                "langCode": "it",
                "original": "summarizer:0_it"
            },
            "mt:3": {
                "language": "Italian",
                "type": "mt",
                "percent": 0,
                "original": "mt:3"
            },
            "postproduction:50_it": {
                "language": "Italian",
                "type": "postproduction",
                "percent": 50,
                "langCode": "it",
                "original": "postproduction:50_it"
            },
            "postproduction:70_it": {
                "language": "Italian",
                "type": "postproduction",
                "percent": 70,
                "langCode": "it",
                "original": "postproduction:70_it"
            },
            "postproduction:90_it": {
                "language": "Italian",
                "type": "postproduction",
                "percent": 90,
                "langCode": "it",
                "original": "postproduction:90_it"
            },
            "tts:1": {
                "language": "German",
                "type": "tts",
                "percent": 0,
                "original": "tts:1"
            },
            "tts:0": {
                "language": "English",
                "type": "tts",
                "percent": 0,
                "original": "tts:0"
            },
            "tts:2": {
                "language": "Italian",
                "type": "tts",
                "percent": 0,
                "original": "tts:2"
            }
        },
        "sessionID": "317374",
        "activeLanguages": [
            "Transcript",
            "English",
            "German",
            "Greek",
            "Italian"
        ]
    },
    "objectType": "info"
}

- The activeLanguages fields show languages that are available for the session.
- computedSenders show a mapping between data raw sender name (mt:1, mt:0, postproduction:*, ...) and the language name.

### message text

{
    "message": "",
    "status": 200,
    "data": {
        "texts": [
            {
                "text": " ",
                "isFinal": false,
                "textId": 0,
                "etime": 0,
                "stime": 0,
                "sender": "Greek",
                "rawSender": "postproduction:90_el",
                "senderDetail": {
                    "language": "Greek",
                    "type": "postproduction",
                    "percent": 90,
                    "langCode": "el",
                    "original": "postproduction:90_el"
                }
            }
        ]
    },
    "objectType": "texts"
}

- The rawSender is the raw sender name.
- isFinal is the same 

### message tts
{"message":"","status":200,"data":{"type":"chunk-info","index":3,"language":"German","rawSender":"tts:1","senderDetail":{"language":"German","type":"tts","percent":0,"original":"tts:1"},"url":"https://vais:eiliepo0kiu7Giec@lt2srv.iar.kit.edu/ltapi/stream/data?name=Data/317374/5"},"objectType":"raw_pcm"}

This is similar to the tts message of the app_2way_v3

## Display logic
Structure the screen as follow:
1. Control area (top)
The control area controls the following:
- The language users want to display on the content area.
- The post production percentage (we call it "Shortening level").
- Font size

2. Content area (bottom)
- Review the app_desc_part3.md of app_2way_v3 app to see more detail of how to render the content logic. You can also refer to the translation result panel.

## Performance notes
- When the websocket connected, there can be large delay until data is received.
Also there can be huge amount of existing text, tts messages return. Skip all existing tts message. But you need to consider performance issue because if there are many languages, the number of messages is huge. Think of a solution to make it smooth.
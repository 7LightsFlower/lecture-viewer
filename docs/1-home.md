# Home screne
Create a home screen with QR code scan feature. Accept only lecture app links (see below), resolve `link_record`, and open the session URL in the system browser.

Add the QR button on the app bar top left. And also when the main screen content is empty, add the QR button there and some descriptions.

The home screen later will contains a list of meeting items after each QR code scan. But it is not available for now.

The QR accepts only the link: https://lectureviewer.app.link/Il4A2yzQrPb?link_record=lt2srv.iar.kit.edu/mobile/session/tkq1221114001-lecture

Use Branch.io (`flutter_branch_sdk`) for https://lectureviewer.app.link so tapping the link opens the app; resolve `link_record` and open the session URL in the system browser.

# Setting screen
An app bar setting and a setting screen with the following fields:
1. Keep screen on while recording
2. Theme: dark/light/auto mode
3. Advanced section: switching between production and testing

Follow the app app_2way_v3 for the style and architecture.
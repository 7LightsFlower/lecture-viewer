On viewer app: The websocket can return info message below
 {"message":"connected","status":200,"data":{"status":"session_end","reason":"session_already_over"},"objectType":"info"}

 indicating that the session is already over, this in case, show a dialog and when user click ok, return to the home screen. Do not clear any history data in this case
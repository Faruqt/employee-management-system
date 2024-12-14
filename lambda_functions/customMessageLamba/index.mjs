const reset_password = async (event) => {
  let code = event.request.codeParameter;
  let name = event.request.userAttributes.name ;
  let message =
    "Hello " + name + " ,\n" +
    "Your password reset code is " +
    code +
    ".\n" +
    "This code will expire in 24 hours.";

  event.response = {
    emailSubject: "Reset your account password",
    emailMessage: message
  };

  return event;
};

const admin_create_user_message = async (event) => {
  let username = event.request.usernameParameter;
  let password = event.request.codeParameter;
  let message =
    "Hello!,\n" +
    "Welcome to the employee management system, here are your credentials: username " +
    username +
    " password \n" +
    password ;
    
  event.response = {
    emailSubject: "Welcome to the employee management system",
    emailMessage: message
  };
  return event;
};

export const handler = async (event) => {
  switch (event.triggerSource) {
    case "CustomMessage_AdminCreateUser": //When the user is created with adminCreateUser() API
      return admin_create_user_message(event);
    case "CustomMessage_ForgotPassword": //Forgot password request initiated by user
      return reset_password(event);
    default:
      return event;
  }
};

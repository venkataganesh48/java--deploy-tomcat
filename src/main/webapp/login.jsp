<%@ page session="false" %>
<html>
  <head>
    <title>Login - Ecomm App</title>
  </head>
  <body>
    <h2>Please Log In</h2>
    <form method="post" action="j_security_check">
      <label for="j_username">Username:</label>
      <input type="admin" name="j_username" id="j_username" required /><br><br>

      <label for="j_password">Password:</label>
      <input type="admin" name="j_password" id="j_password" required /><br><br>

      <input type="submit" value="Login" />
    </form>
  </body>
</html>

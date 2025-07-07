package com.ecomm;

import java.io.;
import javax.servlet.;
import javax.servlet.http.*;

public class HelloServlet extends HttpServlet {
protected void doGet(HttpServletRequest request, HttpServletResponse response)
throws ServletException, IOException {
response.setContentType("text/html");
PrintWriter out = response.getWriter();
out.println("<h2>Hello from HelloServlet!</h2>");
}
}

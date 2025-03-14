package com.daryllmoya.projectxyz.authservice;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/** Main entry point for the Authentication Service. */
@SpringBootApplication
public class AuthServiceApplication {

  /**
   * Starts the application.
   *
   * @param args command-line arguments
   */
  public static void main(String[] args) {
    SpringApplication.run(AuthServiceApplication.class, args);
  }
}

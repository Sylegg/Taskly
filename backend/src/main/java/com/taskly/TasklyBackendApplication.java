package com.taskly;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.security.autoconfigure.UserDetailsServiceAutoConfiguration;

@org.springframework.scheduling.annotation.EnableScheduling
@SpringBootApplication(exclude = UserDetailsServiceAutoConfiguration.class)
public class TasklyBackendApplication {

	public static void main(String[] args) {
		SpringApplication.run(TasklyBackendApplication.class, args);
	}

}

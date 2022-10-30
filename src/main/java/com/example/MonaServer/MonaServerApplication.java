package com.example.MonaServer;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration;

@SpringBootApplication
public class MonaServerApplication {

	public static void main(String[] args) {
		SpringApplication.run(MonaServerApplication.class, args);
	}

}

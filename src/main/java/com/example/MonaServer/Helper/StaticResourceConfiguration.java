package com.example.MonaServer.Helper;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class StaticResourceConfiguration implements WebMvcConfigurer {

    private static final String[] CLASSPATH_RESOURCE_LOCATIONS = {
            "classpath:/static/app", "classpath:/META-INF/resources/", "classpath:/resources/",
            "classpath:/static/", "classpath:/public/" };

    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        if (!registry.hasMappingForPattern("/public/projects/**")) {
            registry.addResourceHandler("/public/projects/**").addResourceLocations(
                    "classpath:/static/projects/");
        }
        if (!registry.hasMappingForPattern("/static/recover/**")) {
            registry.addResourceHandler("/static/recover/**").addResourceLocations(
                    "classpath:/static/recover/");
        }
        if (!registry.hasMappingForPattern("/public/app/**")) {
            registry.addResourceHandler("/public/app/**").addResourceLocations(
                    "classpath:/static/app/");
        }
        registry.addResourceHandler("/**")
                .addResourceLocations(CLASSPATH_RESOURCE_LOCATIONS);
    }
}
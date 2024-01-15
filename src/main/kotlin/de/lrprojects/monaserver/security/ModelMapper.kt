package de.lrprojects.monaserver.security

import org.modelmapper.ModelMapper
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration


@Configuration
class ModelMapper {

    @Bean
    fun modelMapper(): ModelMapper {
        return ModelMapper()
    }

}
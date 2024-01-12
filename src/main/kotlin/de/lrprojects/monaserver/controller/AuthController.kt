package de.lrprojects.monaserver.controller

import org.openapitools.api.AuthApi
import org.openapitools.model.*
import org.springframework.http.ResponseEntity

class AuthController : AuthApi {
    override fun createUser(createUser: CreateUser?): ResponseEntity<String> {
        return super.createUser(createUser)
    }


    override fun generateDeleteCode(username: String?): ResponseEntity<Void> {
        return super.generateDeleteCode(username)
    }

    override fun requestPasswordRecovery(username: String?): ResponseEntity<Void> {
        return super.requestPasswordRecovery(username)
    }

    override fun userLogin(userLoginRequest: UserLoginRequest?): ResponseEntity<UserLogin200Response> {
        return super.userLogin(userLoginRequest)
    }
}
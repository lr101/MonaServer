package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver.excepetion.UserExistsException

interface AuthService {

    @Throws(UserExistsException::class)
    fun signup(username: String, password: String, email: String) :  String

    fun login(username: String, password: String) : String

    fun recoverPassword(username: String)

    fun requestDeleteCode(username: String)

}
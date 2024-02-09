package de.lrprojects.monaserver.controller

import de.lrprojects.monaserver.api.UsersApi
import de.lrprojects.monaserver.api.UsersApiDelegate
import de.lrprojects.monaserver.excepetion.UserNotFoundException
import de.lrprojects.monaserver.model.UpdateUserProfileImage200Response
import de.lrprojects.monaserver.model.User
import de.lrprojects.monaserver.service.api.UserService
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.http.ResponseEntity
import org.springframework.stereotype.Component


@Component
class UserController (@Autowired val userService: UserService) : UsersApiDelegate {
    override fun deleteUser(username: String, code: Int): ResponseEntity<Void> {
        return try {
            userService.deleteUser(username, code)
            ResponseEntity.ok().build()
        } catch (e: UserNotFoundException) {
            ResponseEntity.notFound().build()
        } catch (e: Exception) {
            ResponseEntity.internalServerError().build()
        }

    }

    override fun getUserProfileImage(username: String): ResponseEntity<ByteArray> {
        return try {
            val image = userService.getUserProfileImage(username)
            ResponseEntity.ok(image)
        } catch (e: UserNotFoundException) {
            ResponseEntity.notFound().build()
        } catch (e: Exception) {
            ResponseEntity.internalServerError().build()
        }

    }

    override fun getUserProfileImageSmall(username: String): ResponseEntity<ByteArray> {
        return try {
            val image = userService.getUserProfileImageSmall(username)
            ResponseEntity.ok(image)
        } catch (e: UserNotFoundException) {
            ResponseEntity.notFound().build()
        } catch (e: Exception) {
            ResponseEntity.internalServerError().build()
        }

    }

    override fun updateUser(username: String, user: User): ResponseEntity<String> {
        return try {
            val token = userService.updateUser(username, user)
            ResponseEntity.ok(token)
        } catch (e: UserNotFoundException) {
            ResponseEntity.notFound().build()
        } catch (e: Exception) {
            ResponseEntity.internalServerError().build()
        }

    }

    override fun updateUserProfileImage(
        username: String,
        body: ByteArray,
    ): ResponseEntity<UpdateUserProfileImage200Response> {
        return try {
            val images = userService.updateUserProfileImage(username, body)
            return ResponseEntity.ok(images)
        } catch (e: UserNotFoundException) {
            ResponseEntity.notFound().build()
        } catch (e: Exception) {
            ResponseEntity.internalServerError().build()
        }

    }



}
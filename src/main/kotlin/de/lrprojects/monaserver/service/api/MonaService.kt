package de.lrprojects.monaserver.service.api

interface MonaService {


    fun getPinImage(pinId: Long): ByteArray

    fun addPinImage(pinId: Long, image: ByteArray): ByteArray

    fun getPinImagesByIds(ids: MutableList<Long>, compression: Int?, height: Int?): List<ByteArray?>
}
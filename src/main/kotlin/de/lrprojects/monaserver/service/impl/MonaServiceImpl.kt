package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.service.api.MonaService

class MonaServiceImpl : MonaService {
    override fun getPinImage(pinId: Long): ByteArray {
        TODO("Not yet implemented")
    }

    override fun addPinImage(pinId: Long, image: ByteArray): ByteArray {
        TODO("Not yet implemented")
    }

    override fun getPinImagesByIds(ids: MutableList<Long>?, compression: Int?, height: Int?): MutableList<ByteArray> {
        TODO("Not yet implemented")
    }
}
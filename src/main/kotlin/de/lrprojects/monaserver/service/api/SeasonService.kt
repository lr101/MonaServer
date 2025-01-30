package de.lrprojects.monaserver.service.api

interface SeasonService {
    fun createSeason(month: Int, year: Int)
}
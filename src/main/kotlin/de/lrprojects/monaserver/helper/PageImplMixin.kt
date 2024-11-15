package de.lrprojects.monaserver.helper

import com.fasterxml.jackson.annotation.JsonIgnoreProperties

@JsonIgnoreProperties(value = ["pageable"])
abstract class PageImplMixin {}
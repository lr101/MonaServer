package de.lrprojects.monaserver.helper

import com.fasterxml.jackson.annotation.JsonIgnoreProperties

/**
 * Allows for caching of pageable results by ignoring the pageable property
 */
@JsonIgnoreProperties(value = ["pageable"])
abstract class PageImplMixin {}
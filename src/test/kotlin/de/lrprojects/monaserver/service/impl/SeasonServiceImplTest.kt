package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.converter.toSeasonDto
import de.lrprojects.monaserver.entity.GroupSeason
import de.lrprojects.monaserver.entity.Season
import de.lrprojects.monaserver.entity.User
import de.lrprojects.monaserver.entity.UserSeason
import de.lrprojects.monaserver.repository.GroupRepository
import de.lrprojects.monaserver.repository.GroupSeasonRepository
import de.lrprojects.monaserver.repository.SeasonRepository
import de.lrprojects.monaserver.repository.UserRepository
import de.lrprojects.monaserver.repository.UserSeasonRepository
import de.lrprojects.monaserver.service.api.RankingService
import de.lrprojects.monaserver_api.model.SeasonItemDto
import de.lrprojects.monaserver_api.model.UserInfoDto
import de.lrprojects.monaserver_api.model.UserRankingDtoInner
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`
import org.mockito.junit.jupiter.MockitoExtension
import org.mockito.kotlin.any
import org.mockito.kotlin.argumentCaptor
import org.mockito.kotlin.eq
import org.mockito.kotlin.mock
import java.util.*

@ExtendWith(MockitoExtension::class)
class SeasonServiceImplTest {

 private lateinit var seasonService: SeasonServiceImpl
 private val userSeasonRepository: UserSeasonRepository = mock()
 private val groupSeasonRepository: GroupSeasonRepository = mock()
 private val seasonRepository: SeasonRepository = mock()
 private val rankingService: RankingService = mock()
 private val userRepository: UserRepository = mock()
 private val groupRepository: GroupRepository = mock()

 @BeforeEach
 fun setUp() {
  seasonService = SeasonServiceImpl(
   userSeasonRepository,
   groupSeasonRepository,
   seasonRepository,
   rankingService,
   userRepository,
   groupRepository
  )
 }

 @Test
 fun `createSeason should create a new Season`() {
  // Arrange
  val month = 5
  val year = 2023
  val userId = UUID.randomUUID()
  // Act
  // Create a UserRankingDtoInner instance


  val userRanking = UserRankingDtoInner().also {
   it.userInfoDto = UserInfoDto("username", userId)
   it.rankNr = 1
   it.points = 50
  }

  val user = User("username", "psw").also {
   it.id = userId
  }

  `when`(userRepository.findById(userId)).thenReturn(Optional.of(user))

  `when`(seasonRepository.save(any<Season>())).thenAnswer { (it.arguments[0] as Season).copy(id = UUID.randomUUID()) }

  `when`(rankingService.userRanking(eq(null), eq(null), eq(null), any(), eq(null), any())).thenReturn(mutableListOf(userRanking))

  seasonService.createSeason(month, year)

  val seasonCaptor = argumentCaptor<Season>()
  val userSeasonCaptor = argumentCaptor<Set<UserSeason>>()
  val groupSeasonCaptor = argumentCaptor<Set<GroupSeason>>()

  // Verify that the save function is called and capture the argument
  verify(seasonRepository).save(seasonCaptor.capture())
  verify(userSeasonRepository).saveAll(userSeasonCaptor.capture())
  verify(groupSeasonRepository).saveAll(groupSeasonCaptor.capture())



  // Extract the saved season
  val savedSeason = seasonCaptor.firstValue
  val savedUserSeasons = userSeasonCaptor.firstValue
  val savedGroupSeasons = groupSeasonCaptor.firstValue

  // Assert that the season was saved with the correct values
  assertEquals(month, savedSeason.month)
  assertEquals(year, savedSeason.year)
  assertEquals(1, savedSeason.seasonNumber)

  // Assert that the user seasons were saved with the correct values
  assertEquals(1, savedUserSeasons.size)
  assertEquals(userId, savedUserSeasons.first().user.id)
  assertEquals(userRanking.rankNr, savedUserSeasons.first().rank)
  assertEquals(1, savedUserSeasons.first().season.seasonNumber)

  // Assert that the group seasons were saved with the correct values
  assertEquals(0, savedGroupSeasons.size)
 }

 @Test
 fun `getBestGroupSeason should return SeasonItemDto when group has a best season`() {
  // Arrange
  val groupId = UUID.randomUUID()

  // Create a real Season instance.
  val seasonId = UUID.randomUUID()
  val season = Season(
   id = seasonId,
   seasonNumber = 2,
   year = 2023,
   month = 5
  )
  // Create a real GroupSeason instance.
  val groupSeasonId = UUID.randomUUID()
  val groupSeason = GroupSeason(
   id = groupSeasonId,
   season = season,
   numberOfPins = 100,
   rank = 1,
   group = mock()
  )
  `when`(groupSeasonRepository.findBestSeasonOfGroup(groupId)).thenReturn(groupSeason)

  // Act
  val result = seasonService.getBestGroupSeason(groupId)

  // The expected DTO is produced by the extension function.
  val expectedSeasonItemDto = SeasonItemDto(groupSeasonId, season.toSeasonDto(), 100, 1)
  assertEquals(expectedSeasonItemDto, result)
 }

 @Test
 fun `getBestGroupSeason should return null when group has no best season`() {
  // Arrange
  val groupId = UUID.randomUUID()
  `when`(groupSeasonRepository.findBestSeasonOfGroup(groupId)).thenReturn(null)

  // Act
  val result = seasonService.getBestGroupSeason(groupId)

  // Assert
  assertNull(result)
 }

 @Test
 fun `getBestUserSeason should return SeasonItemDto when user has a best season`() {
  // Arrange
  val userId = UUID.randomUUID()

  // Create a real Season instance.
  val seasonId = UUID.randomUUID()
  val season = Season(
   id = seasonId,
   seasonNumber = 3,
   year = 2023,
   month = 6
  )
  // Create a dummy user. (Replace User with your actual user class if needed.)
  val dummyUser = mock<User>() // or use your actual User type: mock<User>()
  // Create a real UserSeason instance.
  val userSeasonId = UUID.randomUUID()
  val userSeason = UserSeason(
   id = userSeasonId,
   user = dummyUser,
   season = season,
   rank = 1,
   numberOfPins = 50
  )
  `when`(userSeasonRepository.findBestSeasonOfUser(userId)).thenReturn(userSeason)

  // Act
  val result = seasonService.getBestUserSeason(userId)

  // The expected DTO is produced by the extension function.
  val expectedSeasonItemDto = SeasonItemDto(userSeasonId, season.toSeasonDto(), 50, 1)
  assertEquals(expectedSeasonItemDto, result)
 }

 @Test
 fun `getBestUserSeason should return null when user has no best season`() {
  // Arrange
  val userId = UUID.randomUUID()
  `when`(userSeasonRepository.findBestSeasonOfUser(userId)).thenReturn(null)

  // Act
  val result = seasonService.getBestUserSeason(userId)

  // Assert
  assertNull(result)
 }
}

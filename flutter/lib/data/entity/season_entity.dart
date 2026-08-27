import 'package:openapi/api.dart';


class SeasonEntity {

  final String seasonId;
  final int month;
  final int year;
  final int seasonNumber;
  final int rank;
  final int points;

  SeasonEntity({
      this.seasonId = "",
      this.month = 0,
      this.year = 0,
      this.seasonNumber = 0,
      this.rank = 0,
      this.points = 0,
      });

  factory SeasonEntity.fromDto(SeasonItemDto dto) {
    return SeasonEntity(
      seasonId: dto.season.id,
      month: dto.season.month,
      year: dto.season.year,
      seasonNumber: dto.season.seasonNumber,
      rank: dto.rank,
      points: dto.points,
    );
  }

  SeasonItemDto toDto() {
    return SeasonItemDto(id: seasonId, season: SeasonDto(id: seasonId, month: month, year: year, seasonNumber: seasonNumber), points: points, rank: rank);
  }
  
}

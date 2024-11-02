part of namidayoutubeinfo;

class _SearchInfoController {
  const _SearchInfoController();

  Future<YoutiPieSearchResult?> search(
    String query, {
    ExecuteDetails? details,
    bool peopleAlsoWatched = true,
  }) async {
    return YoutiPie.search.search(
      query,
      details: details,
      peopleAlsoWatched: peopleAlsoWatched,
    );
  }
}

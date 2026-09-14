enum SearchDurationFilter { all, short, long }

extension SearchDurationFilterLabel on SearchDurationFilter {
  String get label {
    switch (this) {
      case SearchDurationFilter.all:
        return 'Tümü';
      case SearchDurationFilter.short:
        return '3 dakika ve altı';
      case SearchDurationFilter.long:
        return '4 dakika ve üstü';
    }
  }
}

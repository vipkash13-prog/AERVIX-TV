import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'account_dialog.dart';
import 'player_page.dart';
import 'xtream_service.dart';
import 'remote_search_field.dart';

class XtreamBrowserPage extends StatefulWidget {
  final XtreamService service;
  final MediaKind kind;
  const XtreamBrowserPage({
    super.key,
    required this.service,
    required this.kind,
  });
  @override
  State<XtreamBrowserPage> createState() => _XtreamBrowserPageState();
}

class _XtreamBrowserPageState extends State<XtreamBrowserPage> {
  String? _category;
  String _query = '';
  bool _favourites = false, _opening = false;
  Timer? _search;
  final _searchText = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'xtream-search');
  final _accountFocus = FocusNode(debugLabel: 'xtream-account');
  final _allCategoriesFocus = FocusNode(debugLabel: 'xtream-category-all');
  final _favouritesFocus = FocusNode(debugLabel: 'xtream-favourites');
  final _clearFocus = FocusNode(debugLabel: 'xtream-search-clear');
  final _resultNodes = <String, FocusNode>{};
  final _categoryNodes = <String, FocusNode>{};
  final _resultsScroll = ScrollController(),
      _categoriesScroll = ScrollController();
  double _categoryExtent = 56;
  List<MediaEntry> get _entries => service.items(
    widget.kind,
    category: _category,
    query: _query,
    favourites: _favourites,
  );
  FocusNode _resultNode(MediaEntry entry) => _resultNodes.putIfAbsent(
    entry.key,
    () => FocusNode(debugLabel: 'xtream-result-${entry.key}'),
  );
  FocusNode _categoryNode(String id) => _categoryNodes.putIfAbsent(
    id,
    () => FocusNode(debugLabel: 'xtream-category-$id'),
  );
  void _focusCategory([int? index]) {
    final categories = service.categories(widget.kind);
    final selected =
        index ??
        (_category == null
            ? -1
            : categories.indexWhere((c) => c.id == _category));
    final target = selected.clamp(-1, categories.length - 1);
    if (_categoriesScroll.hasClients) {
      _categoriesScroll.jumpTo(
        ((target + 1) * _categoryExtent).clamp(
          0.0,
          _categoriesScroll.position.maxScrollExtent,
        ),
      );
    }
    (target < 0 ? _allCategoriesFocus : _categoryNode(categories[target].id))
        .requestFocus();
  }

  void _focusResults() {
    if (_entries.isEmpty) {
      _focusCategory();
      return;
    }
    if (_resultsScroll.hasClients) _resultsScroll.jumpTo(0);
    _resultNode(_entries.first).requestFocus();
  }

  void _submitSearch(String value) {
    _search?.cancel();
    setState(() => _query = value);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusResults();
    });
  }

  Widget _categoryRow(String? id, String title, int index, int count) =>
      CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowLeft): _focusResults,
          const SingleActivator(LogicalKeyboardKey.arrowRight): () {},
          const SingleActivator(LogicalKeyboardKey.arrowUp): () => index < 0
              ? _searchFocus.requestFocus()
              : _focusCategory(index - 1),
          const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
              _focusCategory((index + 1).clamp(-1, count - 1)),
        },
        child: ListTile(
          key: ValueKey('xtream-category-${id ?? 'all'}'),
          focusNode: id == null ? _allCategoriesFocus : _categoryNode(id),
          selected: _category == id,
          title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
          onTap: () => setState(() => _category = id),
        ),
      );

  XtreamService get service => widget.service;
  @override
  void initState() {
    super.initState();
    service.addListener(_updated);
    unawaited(_load());
  }

  Future<void> _load() async {
    await service.ready;
    if (!service.loaded(widget.kind)) await service.refresh(widget.kind);
  }

  void _updated() {
    if (mounted)
      setState(() {
        if (_category != null &&
            !service.categories(widget.kind).any((c) => c.id == _category))
          _category = null;
      });
  }

  @override
  void dispose() {
    service.removeListener(_updated);
    _search?.cancel();
    _searchText.dispose();
    for (final node in [
      _searchFocus,
      _accountFocus,
      _allCategoriesFocus,
      _favouritesFocus,
      _clearFocus,
      ..._resultNodes.values,
      ..._categoryNodes.values,
    ]) {
      node.dispose();
    }
    _resultsScroll.dispose();
    _categoriesScroll.dispose();
    super.dispose();
  }

  Future<void> _options(MediaEntry item) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(item.name),
        children: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(context, 'favourite'),
            child: Text(
              service.favourite(item)
                  ? 'إزالة من المفضلة'
                  : 'إضافة إلى المفضلة',
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'block'),
            child: const Text('حظر هذا المحتوى'),
          ),
        ],
      ),
    );
    if (action == 'favourite') await service.toggleFavourite(item);
    if (action == 'block') await service.block(item.kind, item.id);
  }

  Future<void> _blockCategory() async {
    final id = _category;
    if (id == null) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حظر التصنيف؟'),
        content: const Text('سيُخفى محتواه من القوائم والبحث والمفضلة.'),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حظر'),
          ),
        ],
      ),
    );
    if (accepted == true) await service.block(widget.kind, id, category: true);
  }

  Future<void> _manageBlocks() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AnimatedBuilder(
        animation: service,
        builder: (context, _) => AlertDialog(
          title: const Text('الحظر اليدوي'),
          content: SizedBox(
            width: 500,
            height: 300,
            child: service.manualBlocks.isEmpty
                ? const Center(child: Text('لا يوجد حظر يدوي'))
                : ListView(
                    children: service.manualBlocks
                        .map(
                          (key) => ListTile(
                            title: Text(
                              '${MediaKind.values.firstWhere((kind) => kind.name == key.split(':').first).label} · ${key.split(':').last}',
                            ),
                            subtitle: Text(
                              key.contains(':category:') ? 'تصنيف' : 'عنصر',
                            ),
                            trailing: TextButton(
                              onPressed: () => service.unblock(key),
                              child: const Text('إلغاء الحظر'),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          actions: [
            TextButton(
              autofocus: true,
              onPressed: () => Navigator.pop(context),
              child: const Text('رجوع'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(MediaEntry item) async {
    if (_opening || !service.isAllowed(item)) return;
    setState(() => _opening = true);
    try {
      if (item.kind == MediaKind.movie && !await service.checkMovie(item))
        return;
      if (!mounted) return;
      if (item.kind == MediaKind.series) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => XtreamSeriesPage(service: service, series: item),
          ),
        );
      } else {
        final playlist = item.kind == MediaKind.live
            ? service.items(
                widget.kind,
                category: _category,
                favourites: _favourites,
              )
            : [item];
        final index = playlist.indexWhere((m) => m.id == item.id);
        if (index < 0) return;
        final category = _category;
        final favourites = _favourites;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => XtreamPlayerPage(
              service: service,
              playlist: playlist,
              index: index,
              currentPlaylist: item.kind == MediaKind.live
                  ? () => service.items(
                      MediaKind.live,
                      category: category,
                      favourites: favourites,
                    )
                  : null,
            ),
          ),
        );
      }
    } on XtreamFailure catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = service.categories(widget.kind);
    final entries = _entries;
    _categoryExtent = (MediaQuery.textScalerOf(context).scale(16) / 16 * 56)
        .clamp(56.0, double.infinity);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF090E16),
        appBar: AppBar(
          title: Text(widget.kind.label),
          actions: [
            IconButton(
              tooltip: 'تحديث الاشتراك',
              onPressed: service.loading(widget.kind)
                  ? null
                  : () => service.refresh(widget.kind),
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'بيانات الاشتراك',
              focusNode: _accountFocus,
              onPressed: () async {
                if (await showXtreamAccount(context, service))
                  await service.refresh(widget.kind);
              },
              icon: const Icon(Icons.account_circle_outlined),
            ),
            IconButton(
              tooltip: 'الحظر اليدوي',
              onPressed: _manageBlocks,
              icon: const Icon(Icons.block),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: RemoteSearchField(
                      controller: _searchText,
                      focusNode: _searchFocus,
                      onSubmit: _submitSearch,
                      onUp: _accountFocus.requestFocus,
                      onLeft: () => _query.isEmpty
                          ? _favouritesFocus.requestFocus()
                          : _clearFocus.requestFocus(),
                      onRight: _focusCategory,
                      onChanged: (value) {
                        _search?.cancel();
                        _search = Timer(const Duration(milliseconds: 220), () {
                          if (mounted) setState(() => _query = value);
                        });
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: 'مسح البحث',
                    focusNode: _clearFocus,
                    onPressed: _searchText.text.isEmpty
                        ? null
                        : () {
                            _searchText.clear();
                            _search?.cancel();
                            setState(() => _query = '');
                            _searchFocus.requestFocus();
                          },
                    icon: const Icon(Icons.clear),
                  ),
                  const SizedBox(width: 16),
                  FilterChip(
                    label: const Text('المفضلة'),
                    focusNode: _favouritesFocus,
                    selected: _favourites,
                    onSelected: (value) => setState(() => _favourites = value),
                  ),
                  if (_category != null)
                    TextButton(
                      onPressed: _blockCategory,
                      child: const Text('حظر التصنيف'),
                    ),
                ],
              ),
            ),
            if (service.loading(widget.kind) || _opening)
              const LinearProgressIndicator(color: Color(0xFFFFD68A)),
            if (service.error(widget.kind) != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  service.error(widget.kind)!,
                  style: const TextStyle(color: Colors.amber),
                ),
              ),
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 240,
                    child: ListView.builder(
                      controller: _categoriesScroll,
                      itemExtent: _categoryExtent,
                      itemCount: categories.length + 1,
                      itemBuilder: (context, index) => index == 0
                          ? _categoryRow(
                              null,
                              'جميع التصنيفات',
                              -1,
                              categories.length,
                            )
                          : _categoryRow(
                              categories[index - 1].id,
                              categories[index - 1].name,
                              index - 1,
                              categories.length,
                            ),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: entries.isEmpty
                        ? Center(
                            child: Text(
                              service.loading(widget.kind)
                                  ? 'جارٍ تحميل المحتوى…'
                                  : 'لا يوجد محتوى متاح',
                            ),
                          )
                        : ListView.builder(
                            controller: _resultsScroll,
                            key: ValueKey(
                              'xtream-items-${widget.kind.name}-${_category ?? 'all'}-$_favourites-$_query',
                            ),
                            itemCount: entries.length,
                            itemBuilder: (context, index) {
                              final item = entries[index];
                              return _RemoteMediaRow(
                                key: ValueKey('xtream-item-${item.key}'),
                                focusNode: _resultNode(item),
                                onKey: (event) {
                                  if (event is KeyDownEvent ||
                                      event is KeyRepeatEvent) {
                                    if (event.logicalKey ==
                                            LogicalKeyboardKey.arrowUp &&
                                        index == 0) {
                                      _searchFocus.requestFocus();
                                      return KeyEventResult.handled;
                                    }
                                    if (event.logicalKey ==
                                        LogicalKeyboardKey.arrowRight) {
                                      _focusCategory();
                                      return KeyEventResult.handled;
                                    }
                                  }
                                  return KeyEventResult.ignored;
                                },
                                autofocus: index == 0 && !_searchFocus.hasFocus,
                                title:
                                    '${widget.kind == MediaKind.live ? '${index + 1} · ' : ''}${item.name}',
                                onOpen: () => _open(item),
                                onOptions: () => _options(item),
                                favourite: service.favourite(item),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RemoteMediaRow extends StatefulWidget {
  final String title;
  final bool autofocus, favourite;
  final VoidCallback onOpen;
  final VoidCallback? onOptions;
  final FocusNode? focusNode;
  final ValueChanged<bool>? onFocused;
  final KeyEventResult Function(KeyEvent)? onKey;
  const _RemoteMediaRow({
    super.key,
    required this.title,
    required this.onOpen,
    this.onOptions,
    this.focusNode,
    this.onFocused,
    this.onKey,
    this.autofocus = false,
    this.favourite = false,
  });
  @override
  State<_RemoteMediaRow> createState() => _RemoteMediaRowState();
}

class _RemoteMediaRowState extends State<_RemoteMediaRow> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) => Focus(
    onKeyEvent: (_, event) {
      final result = widget.onKey?.call(event);
      if (result != null && result != KeyEventResult.ignored) return result;
      if (event is KeyDownEvent &&
          [
            LogicalKeyboardKey.contextMenu,
            LogicalKeyboardKey.keyM,
            LogicalKeyboardKey.gameButtonX,
          ].contains(event.logicalKey)) {
        widget.onOptions?.call();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: FocusableActionDetector(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onOpen();
            return null;
          },
        ),
      },
      onFocusChange: (focused) {
        setState(() => _focused = focused);
        widget.onFocused?.call(focused);
        if (focused)
          Scrollable.ensureVisible(
            context,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
            duration: const Duration(milliseconds: 100),
          );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: _focused ? const Color(0xFF48351B) : const Color(0xFF151B25),
          border: Border.all(
            color: _focused ? const Color(0xFFFFD68A) : Colors.white24,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: ListTile(
          onTap: widget.onOpen,
          onLongPress: widget.onOptions,
          title: Text(
            widget.title,
            style: const TextStyle(color: Colors.white, fontSize: 21),
          ),
          leading: widget.favourite
              ? const Icon(Icons.star, color: Colors.amber)
              : null,
          trailing: widget.onOptions == null
              ? null
              : IconButton(
                  tooltip: 'المفضلة والحظر — زر القائمة',
                  onPressed: widget.onOptions,
                  icon: const Icon(Icons.more_vert),
                ),
        ),
      ),
    ),
  );
}

class XtreamSeriesPage extends StatefulWidget {
  final XtreamService service;
  final MediaEntry series;
  const XtreamSeriesPage({required this.service, required this.series});
  @override
  State<XtreamSeriesPage> createState() => _SeriesPageState();
}

class _SeriesPageState extends State<XtreamSeriesPage> {
  late Future<List<MediaEpisode>> _episodes = widget.service.episodes(
    widget.series,
  );
  int? _season;
  final _scrolls = <int, ScrollController>{};
  final _focus = <String, FocusNode>{};
  final _lastEpisode = <int, String>{};
  Timer? _backCooldown;
  bool _returning = false, _playing = false;
  ScrollController _scroll(int season) =>
      _scrolls.putIfAbsent(season, () => ScrollController());
  FocusNode _node(String id) =>
      _focus.putIfAbsent(id, () => FocusNode(debugLabel: 'episode-$id'));
  Future<void> _playEpisode(MediaEpisode episode, int season) async {
    if (_playing) return;
    _playing = true;
    _season = season;
    _lastEpisode[season] = episode.media.id;
    final scroll = _scroll(season);
    final offset = scroll.hasClients ? scroll.offset : 0.0;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => XtreamPlayerPage(
            service: widget.service,
            playlist: [episode.media],
            series: widget.series,
          ),
        ),
      );
    } finally {
      _playing = false;
      if (mounted) {
        // Android remotes may emit both a key and a system Back during the
        // player's reverse transition. Keep this route through that transition.
        setState(() => _returning = true);
        _backCooldown?.cancel();
        _backCooldown = Timer(const Duration(milliseconds: 350), () {
          if (mounted) setState(() => _returning = false);
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (scroll.hasClients)
            scroll.jumpTo(offset.clamp(0.0, scroll.position.maxScrollExtent));
          _node(episode.media.id).requestFocus();
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.service.removeListener(_changed);
    _backCooldown?.cancel();
    for (final controller in _scrolls.values) {
      controller.dispose();
    }
    for (final node in _focus.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !_returning) Navigator.of(context).pop();
    },
    child: Focus(
      canRequestFocus: false,
      onKeyEvent: (_, event) {
        if (_returning &&
            [
              LogicalKeyboardKey.escape,
              LogicalKeyboardKey.goBack,
              LogicalKeyboardKey.gameButtonB,
            ].contains(event.logicalKey))
          return KeyEventResult.handled;
        return KeyEventResult.ignored;
      },
      child: Directionality(
        key: ValueKey('series-episodes-${widget.series.id}'),
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFF090E16),
          appBar: AppBar(
            title: Text(
              widget.service.isAllowed(widget.series)
                  ? widget.series.name
                  : 'المحتوى غير متاح',
            ),
          ),
          body: !widget.service.isAllowed(widget.series)
              ? const Center(child: Text('المحتوى محظور'))
              : FutureBuilder<List<MediaEpisode>>(
                  future: _episodes,
                  builder: (context, snapshot) {
                    if (snapshot.hasError)
                      return Center(
                        child: TextButton(
                          onPressed: () => setState(
                            () => _episodes = widget.service.episodes(
                              widget.series,
                            ),
                          ),
                          child: const Text(
                            'تعذر تحميل الحلقات — إعادة المحاولة',
                          ),
                        ),
                      );
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());
                    final all = snapshot.data!
                        .where(
                          (e) => widget.service.episodeAllowed(
                            e.media,
                            widget.series,
                          ),
                        )
                        .toList();
                    final seasons = all.map((e) => e.season).toSet().toList()
                      ..sort();
                    final selected =
                        _season ?? (seasons.isEmpty ? null : seasons.first);
                    final episodes = all
                        .where((e) => e.season == selected)
                        .toList();
                    return Column(
                      children: [
                        Wrap(
                          spacing: 12,
                          children: seasons
                              .map(
                                (s) => ChoiceChip(
                                  key: ValueKey('series-season-$s'),
                                  label: Text('الموسم $s'),
                                  selected: s == selected,
                                  onSelected: (_) =>
                                      setState(() => _season = s),
                                ),
                              )
                              .toList(),
                        ),
                        Expanded(
                          child: episodes.isEmpty
                              ? const Center(child: Text('لا توجد حلقات متاحة'))
                              : ListView.builder(
                                  key: PageStorageKey(
                                    'series-${widget.series.id}-season-$selected',
                                  ),
                                  controller: _scroll(selected!),
                                  itemCount: episodes.length,
                                  itemBuilder: (context, index) {
                                    final episode = episodes[index];
                                    return _RemoteMediaRow(
                                      key: ValueKey(
                                        'series-episode-${widget.series.id}-${episode.media.id}',
                                      ),
                                      focusNode: _node(episode.media.id),
                                      onFocused: (focused) {
                                        if (focused)
                                          _lastEpisode[selected] =
                                              episode.media.id;
                                      },
                                      autofocus:
                                          (_lastEpisode[selected] ??
                                              episodes.first.media.id) ==
                                          episode.media.id,
                                      title:
                                          '${episode.order} · ${episode.media.name}',
                                      onOpen: () =>
                                          _playEpisode(episode, selected),
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ),
    ),
  );
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/catalog.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';
import '../../shared/widgets/category_icon.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/product_card.dart';
import '../../state/search_history.dart';

/// Search across all listings. Also used as the page for a single category.
class SearchScreen extends StatefulWidget {
  final String? categoryId;
  final bool autofocus;
  const SearchScreen({super.key, this.categoryId, this.autofocus = true});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _q = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String? _category;
  String? _city;
  String? _condition;
  double? _minPrice;
  double? _maxPrice;
  SortBy _sort = SortBy.newest;
  Future<List<Product>>? _results;

  @override
  void initState() {
    super.initState();
    _category = widget.categoryId;
    if (_category != null) WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  int get _activeFilters => [
        _city,
        _condition,
        _minPrice,
        _maxPrice,
        if (widget.categoryId == null) _category,
      ].where((e) => e != null).length;

  bool get _hasCriteria => _query.trim().isNotEmpty || _category != null || _activeFilters > 0;

  void _run() {
    if (!mounted) return;
    if (!_hasCriteria) {
      setState(() => _results = null);
      return;
    }
    setState(() {
      _results = context.read<ProductRepository>().search(SearchFilters(
            query: _query,
            categoryId: _category,
            city: _city,
            condition: _condition,
            minPrice: _minPrice,
            maxPrice: _maxPrice,
            sort: _sort,
          ));
    });
  }

  void _onChanged(String v) {
    _query = v;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _run);
  }

  void _submit(String v) {
    _debounce?.cancel();
    _query = v;
    context.read<SearchHistory>().add(v);
    _run();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.categoryId == null ? null : Catalog.category(widget.categoryId!).name;

    return Scaffold(
      appBar: AppBar(
        title: title != null ? Text(title) : null,
        titleSpacing: title == null ? 0 : null,
        actions: title != null ? const [CartIconButton()] : null,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _q,
                    autofocus: widget.autofocus,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _submit,
                    onChanged: _onChanged,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: title == null ? 'Search JDMart' : 'Search in $title',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _q,
                        builder: (_, v, __) => v.text.isEmpty
                            ? const SizedBox.shrink()
                            : IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _q.clear();
                                  _submit('');
                                },
                              ),
                      ),
                      fillColor: AppColors.greyLight,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Badge(
                  isLabelVisible: _activeFilters > 0,
                  backgroundColor: AppColors.orange,
                  label: Text('$_activeFilters'),
                  child: IconButton.filled(
                    tooltip: 'Filters',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      fixedSize: const Size(48, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _openFilters,
                    icon: const Icon(Icons.tune_rounded, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _results == null ? _suggestions() : _resultsView(),
    );
  }

  Widget _suggestions() {
    final history = context.watch<SearchHistory>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (history.items.isNotEmpty) ...[
          Row(
            children: [
              const Expanded(
                  child: Text('Recent searches', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
              TextButton(onPressed: history.clear, child: const Text('Clear')),
            ],
          ),
          ...history.items.map((r) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history_rounded, color: AppColors.grey),
                title: Text(r),
                trailing: const Icon(Icons.north_west_rounded, size: 18, color: AppColors.grey),
                onTap: () {
                  _q.text = r;
                  _submit(r);
                },
              )),
          const SizedBox(height: 16),
        ],
        const Text('Browse categories', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: Catalog.categories
              .map((c) => ActionChip(
                    avatar: CategoryIcon(category: c, size: 18),
                    label: Text(c.name),
                    onPressed: () {
                      _category = c.id;
                      _run();
                    },
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _resultsView() {
    return FutureBuilder<List<Product>>(
      future: _results,
      builder: (_, snap) {
        if (snap.hasError) return ErrorView(error: snap.error, onRetry: _run);
        if (snap.connectionState != ConnectionState.done) return const LoadingView();
        final results = snap.data ?? const <Product>[];
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('${results.length} ${results.length == 1 ? 'result' : 'results'}',
                          style: const TextStyle(color: AppColors.grey, fontWeight: FontWeight.w500)),
                    ),
                    PopupMenuButton<SortBy>(
                      initialValue: _sort,
                      onSelected: (s) {
                        _sort = s;
                        _run();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: SortBy.newest, child: Text('Newest first')),
                        PopupMenuItem(value: SortBy.priceLow, child: Text('Price: low to high')),
                        PopupMenuItem(value: SortBy.priceHigh, child: Text('Price: high to low')),
                        PopupMenuItem(value: SortBy.popular, child: Text('Most viewed')),
                      ],
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Row(
                          children: [
                            Icon(Icons.sort_rounded, size: 18, color: AppColors.blue),
                            SizedBox(width: 4),
                            Text('Sort', style: TextStyle(color: AppColors.blue, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_activeFilters > 0)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      if (_category != null && widget.categoryId == null)
                        _chip(Catalog.category(_category!).name, () => _category = null),
                      if (_city != null) _chip(_city!, () => _city = null),
                      if (_condition != null) _chip(_condition!, () => _condition = null),
                      if (_minPrice != null) _chip('From ${Fmt.price(_minPrice!)}', () => _minPrice = null),
                      if (_maxPrice != null) _chip('Up to ${Fmt.price(_maxPrice!)}', () => _maxPrice = null),
                    ],
                  ),
                ),
              ),
            if (results.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No products found',
                  message: 'Try a different word or remove some filters.',
                ),
              )
            else
              ProductSliverGrid(products: results),
          ],
        );
      },
    );
  }

  Widget _chip(String label, VoidCallback clear) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InputChip(
          label: Text(label, style: const TextStyle(fontSize: 12)),
          onDeleted: () {
            clear();
            _run();
          },
          deleteIconColor: AppColors.grey,
        ),
      );

  Future<void> _openFilters() async {
    String? cat = _category;
    String? city = _city;
    String? cond = _condition;
    final min = TextEditingController(text: _minPrice?.toStringAsFixed(0) ?? '');
    final max = TextEditingController(text: _maxPrice?.toStringAsFixed(0) ?? '');

    final apply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4))),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(child: Text('Filters', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                      TextButton(
                        onPressed: () => setS(() {
                          if (widget.categoryId == null) cat = null;
                          city = null;
                          cond = null;
                          min.clear();
                          max.clear();
                        }),
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                  if (widget.categoryId == null) ...[
                    const _Label('Category'),
                    DropdownButtonFormField<String?>(
                      key: ValueKey('cat-$cat'), // rebuild when Reset is tapped
                      initialValue: cat,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All categories')),
                        ...Catalog.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                      ],
                      onChanged: (v) => setS(() => cat = v),
                    ),
                  ],
                  const _Label('Location'),
                  DropdownButtonFormField<String?>(
                    key: ValueKey('city-$city'),
                    initialValue: city,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All of Sierra Leone')),
                      ...Catalog.cities.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                    ],
                    onChanged: (v) => setS(() => city = v),
                  ),
                  const _Label('Condition'),
                  Wrap(
                    spacing: 8,
                    children: <String?>[null, ...Catalog.conditions]
                        .map((c) => ChoiceChip(
                              label: Text(c ?? 'Any'),
                              selected: cond == c,
                              selectedColor: AppColors.blue,
                              labelStyle: TextStyle(color: cond == c ? Colors.white : AppColors.navy),
                              showCheckmark: false,
                              onSelected: (_) => setS(() => cond = c),
                            ))
                        .toList(),
                  ),
                  const _Label('Price (Le)'),
                  Row(
                    children: [
                      Expanded(child: _priceField(min, 'Min')),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('–')),
                      Expanded(child: _priceField(max, 'Max')),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Show results')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (apply == true) {
      _category = cat;
      _city = city;
      _condition = cond;
      _minPrice = double.tryParse(min.text);
      _maxPrice = double.tryParse(max.text);
      _run();
    }
  }

  Widget _priceField(TextEditingController c, String hint) => TextField(
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(hintText: hint, prefixText: 'Le ', isDense: true),
      );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      );
}

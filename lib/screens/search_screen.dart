import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/seed_data.dart';
import '../models/models.dart';
import '../providers/product_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/product_card.dart';
import '../widgets/category_icon.dart';

class SearchScreen extends StatefulWidget {
  final String? categoryId;
  final bool autofocus;
  const SearchScreen({super.key, this.categoryId, this.autofocus = true});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _q = TextEditingController();
  String _query = '';
  String? _category;
  String? _city;
  String? _condition;
  RangeValues? _price;
  SortBy _sort = SortBy.newest;

  @override
  void initState() {
    super.initState();
    _category = widget.categoryId;
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  int get _activeFilters =>
      [_city, _condition, _price, if (widget.categoryId == null) _category].where((e) => e != null).length;

  void _submit(String v) {
    setState(() => _query = v);
    context.read<ProductProvider>().addRecentSearch(v);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    final results = provider.search(
      query: _query,
      categoryId: _category,
      city: _city,
      condition: _condition,
      minPrice: _price?.start,
      maxPrice: (_price == null || _price!.end >= 20000) ? null : _price!.end,
      sort: _sort,
    );
    final showRecent = _query.isEmpty && widget.categoryId == null && _activeFilters == 0;
    final title = widget.categoryId == null ? null : SeedData.category(widget.categoryId!).name;

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
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: title == null ? 'Search JDMart' : 'Search in $title',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => setState(() {
                                _q.clear();
                                _query = '';
                              }),
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
      body: showRecent ? _recent(provider) : _results(results),
    );
  }

  Widget _recent(ProductProvider provider) {
    final recent = provider.recentSearches;
    const trending = ['Tecno', 'Gara', 'Solar', 'Rice', 'Laptop', 'Generator', 'Kaftan'];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (recent.isNotEmpty) ...[
          Row(
            children: [
              const Expanded(
                  child: Text('Recent searches', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
              TextButton(onPressed: provider.clearRecentSearches, child: const Text('Clear')),
            ],
          ),
          ...recent.map((r) => ListTile(
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
        const Text('Trending in Sierra Leone', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: trending
              .map((t) => ActionChip(
                    avatar: const Icon(Icons.trending_up_rounded, size: 16, color: AppColors.orange),
                    label: Text(t),
                    onPressed: () {
                      _q.text = t;
                      _submit(t);
                    },
                  ))
              .toList(),
        ),
        const SizedBox(height: 24),
        const Text('Browse categories', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: SeedData.categories
              .map((c) => ActionChip(
                    avatar: CategoryIcon(category: c, size: 18),
                    label: Text(c.name),
                    onPressed: () => setState(() => _category = c.id),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _results(List<Product> results) {
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
                  onSelected: (s) => setState(() => _sort = s),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: SortBy.newest, child: Text('Newest first')),
                    PopupMenuItem(value: SortBy.priceLow, child: Text('Price: low to high')),
                    PopupMenuItem(value: SortBy.priceHigh, child: Text('Price: high to low')),
                    PopupMenuItem(value: SortBy.popular, child: Text('Most popular')),
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
                    _chip(SeedData.category(_category!).name, () => setState(() => _category = null)),
                  if (_city != null) _chip(_city!, () => setState(() => _city = null)),
                  if (_condition != null) _chip(_condition!, () => setState(() => _condition = null)),
                  if (_price != null)
                    _chip('Le ${_price!.start.round()} – ${_price!.end.round()}${_price!.end >= 20000 ? '+' : ''}', () => setState(() => _price = null)),
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
  }

  Widget _chip(String label, VoidCallback onRemove) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InputChip(
          label: Text(label, style: const TextStyle(fontSize: 12)),
          onDeleted: onRemove,
          deleteIconColor: AppColors.grey,
        ),
      );

  Future<void> _openFilters() async {
    String? cat = _category;
    String? city = _city;
    String? cond = _condition;
    RangeValues price = _price ?? const RangeValues(0, 20000);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration:
                            BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4))),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                          child: Text('Filters', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                      TextButton(
                        onPressed: () => setS(() {
                          if (widget.categoryId == null) cat = null;
                          city = null;
                          cond = null;
                          price = const RangeValues(0, 20000);
                        }),
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                  if (widget.categoryId == null) ...[
                    const _Label('Category'),
                    DropdownButtonFormField<String?>(
                      value: cat,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All categories')),
                        ...SeedData.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                      ],
                      onChanged: (v) => setS(() => cat = v),
                    ),
                  ],
                  const _Label('Location'),
                  DropdownButtonFormField<String?>(
                    value: city,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All of Sierra Leone')),
                      ...SeedData.cities.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                    ],
                    onChanged: (v) => setS(() => city = v),
                  ),
                  const _Label('Condition'),
                  Wrap(
                    spacing: 8,
                    children: [null, 'New', 'Used', 'Refurbished']
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
                  _Label('Price (Le ${price.start.round()} – Le ${price.end.round()}${price.end >= 20000 ? '+' : ''})'),
                  RangeSlider(
                    values: price,
                    min: 0,
                    max: 20000,
                    divisions: 80,
                    activeColor: AppColors.orange,
                    onChanged: (v) => setS(() => price = v),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _category = cat;
                        _city = city;
                        _condition = cond;
                        final isDefault = price.start == 0 && price.end >= 20000;
                        _price = isDefault ? null : price;
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('Show results'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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

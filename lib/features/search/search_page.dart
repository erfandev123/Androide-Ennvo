// ============================================================================
//  ENNVO — SEARCH SCREEN
//
//  Ported from `src/pages/SearchPage.tsx`: a squircle search field, a row
//  of category pills, recent searches, trending tags and a uniform aspect
//  ratio grid of results.
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/icons/lucide_icons.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const List<String> _categories = [
    'All',
    'People',
    'Posts',
    'Reels',
    'Sounds',
    'Tags',
  ];

  static const List<String> _trending = [
    '#Ennvo',
    '#Reels',
    '#Stories',
    '#Tech',
    '#Music',
    '#Gaming',
    '#Lifestyle',
  ];

  final TextEditingController _query = TextEditingController();
  final List<String> _recent = <String>[];
  int _category = 0;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    // The web app debounces the live search by 200ms.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() {});
    });
  }

  void _commitRecent(String term) {
    final value = term.trim();
    if (value.isEmpty) return;
    setState(() {
      _recent.remove(value);
      _recent.insert(0, value);
      if (_recent.length > 8) _recent.removeRange(8, _recent.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final top = MediaQuery.paddingOf(context).top;
    final hasQuery = _query.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: t.background,
      body: Column(
        children: [
          // --- header -------------------------------------------------
          Padding(
            padding: EdgeInsets.fromLTRB(14, top + 10, 14, 8),
            child: Row(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: LucideIcon(
                    LucideIcons.chevronLeft,
                    size: 24,
                    strokeWidth: 2.4,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: t.isDark
                          ? const Color(0x14FFFFFF)
                          : const Color(0x0F111827),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Row(
                      children: [
                        LucideIcon(
                          LucideIcons.search,
                          size: 17,
                          strokeWidth: 2.2,
                          color: t.textTertiary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _query,
                            onChanged: _onChanged,
                            onSubmitted: _commitRecent,
                            style: EnnvoText.body.copyWith(
                              color: t.textPrimary,
                              fontSize: 14,
                            ),
                            cursorColor: t.accent,
                            decoration: InputDecoration(
                              hintText: 'Search Ennvo',
                              hintStyle: EnnvoText.body.copyWith(
                                color: t.textTertiary,
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _themeToggled = !_themeToggled),
                  child: LucideIcon(
                    _themeToggled ? LucideIcons.sun : LucideIcons.moon,
                    size: 19,
                    strokeWidth: 2.2,
                    color: t.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // --- category pills ----------------------------------------
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final isActive = index == _category;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _category = index),
                  child: AnimatedContainer(
                    duration: EnnvoDurations.dropdown,
                    curve: EnnvoCurves.press,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isActive ? t.accent : t.surfaceAlt,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _categories[index],
                      style: EnnvoText.label.copyWith(
                        color: isActive ? Colors.white : t.textSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // --- results ------------------------------------------------
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 32),
              children: [
                if (!hasQuery) ...[
                  if (_recent.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'RECENT',
                      style: EnnvoText.overlineXs.copyWith(
                        color: t.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final term in _recent)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: LucideIcon(
                          LucideIcons.clock,
                          size: 17,
                          strokeWidth: 2.2,
                          color: t.textTertiary,
                        ),
                        title: Text(
                          term,
                          style: EnnvoText.body.copyWith(color: t.textPrimary),
                        ),
                        trailing: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () =>
                              setState(() => _recent.remove(term)),
                          child: LucideIcon(
                            LucideIcons.x,
                            size: 16,
                            strokeWidth: 2.2,
                            color: t.textTertiary,
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    'TRENDING',
                    style: EnnvoText.overlineXs.copyWith(
                      color: t.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in _trending)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            _query.text = tag;
                            _commitRecent(tag);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: t.surfaceAlt,
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                            ),
                            child: Text(
                              tag,
                              style: EnnvoText.label.copyWith(
                                color: t.textSecondary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ] else
                  _SearchResults(
                    query: _query.text.trim(),
                    category: _categories[_category],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _themeToggled = false;
}

// ============================================================================
//  Results
// ============================================================================
class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.query, required this.category});

  final String query;
  final String category;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          LucideIcon(
            LucideIcons.search,
            size: 42,
            strokeWidth: 1.6,
            color: t.textTertiary,
          ),
          const SizedBox(height: 14),
          Text(
            'Searching for "$query"',
            textAlign: TextAlign.center,
            style: EnnvoText.titleMd.copyWith(color: t.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Results for $category are on the way.',
            textAlign: TextAlign.center,
            style: EnnvoText.body.copyWith(color: t.textSecondary),
          ),
        ],
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/auth/session_manager.dart';
import '../../../core/di/injection.dart';
import '../../../core/router/app_routes.dart';
import '../../../features/social/social_api.dart';
import '../../../features/social/social_view_models.dart';
import '../../components/v21_cosmetics.dart';
import '../../ui_v21.dart';

// =====================================================================
// ARKADAŞLAR (056)
// =====================================================================

/// ARKADAŞLAR: üç sekme — ARKADAŞLAR · İSTEKLER · OYUNCU ARA.
///
/// Arkadaş satırında çevrimiçi durumu ve kupa; dokununca açık profil.
/// İstekler sekmesinde gelenler (KABUL / REDDET) ve gönderilenler (GERİ ÇEK).
/// Arama ada göre, en az 2 harf; sonuçta ARKADAŞ EKLE.
class V21FriendsScreen extends StatelessWidget {
  const V21FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider<FriendsViewModel>(
    create: (_) => FriendsViewModel(getIt<SocialApi>())..load(),
    child: const _FriendsBody(),
  );
}

enum _Sekme { friends, requests, search }

class _FriendsBody extends StatefulWidget {
  const _FriendsBody();

  @override
  State<_FriendsBody> createState() => _FriendsBodyState();
}

class _FriendsBodyState extends State<_FriendsBody> {
  _Sekme _sekme = _Sekme.friends;
  final _arama = TextEditingController();

  @override
  void dispose() {
    _arama.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FriendsViewModel>();
    final l = vm.lists;
    final istek = l.incoming.length;
    return V21InnerPage(
      title: 'ARKADAŞLAR',
      route: AppRoutes.social,
      fallbackRoute: AppRoutes.profile,
      state: !vm.loaded
          ? (vm.isLoading ? V21PageState.loading : (vm.hasError ? V21PageState.error : V21PageState.loading))
          : V21PageState.ready,
      errorMessage: vm.errorMessage,
      onRetry: vm.load,
      onRefresh: vm.refresh,
      children: (context, k) => [
        Row(
          children: [
            for (final (s, etiket) in [
              (_Sekme.friends, 'ARKADAŞLAR (${l.friends.length})'),
              (_Sekme.requests, istek > 0 ? 'İSTEKLER ($istek)' : 'İSTEKLER'),
              (_Sekme.search, 'ARA'),
            ]) ...[
              if (s != _Sekme.friends) SizedBox(width: 6 * k),
              Expanded(
                child: V21FilterPill(
                  key: Key('sekme-${s.name}'),
                  label: etiket,
                  selected: _sekme == s,
                  color: s == _Sekme.requests && istek > 0 ? V21Colors.danger : null,
                  onTap: () => setState(() => _sekme = s),
                  scale: k,
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: 12 * k),
        if (vm.actionError != null || vm.info != null) ...[
          Text(
            vm.actionError ?? vm.info!,
            textAlign: TextAlign.center,
            style: V21Type.label(
              13 * k,
              weight: FontWeight.w800,
              color: vm.actionError != null ? V21Colors.danger : V21Colors.successText,
            ),
          ),
          SizedBox(height: 10 * k),
        ],
        ...switch (_sekme) {
          _Sekme.friends => _arkadaslar(context, vm, k),
          _Sekme.requests => _istekler(context, vm, k),
          _Sekme.search => _ara(context, vm, k),
        },
      ],
    );
  }

  List<Widget> _arkadaslar(BuildContext context, FriendsViewModel vm, double k) {
    final f = vm.lists.friends;
    if (f.isEmpty) {
      return [
        V21EmptyState(
          icon: Icons.group_add_rounded,
          title: 'HENÜZ ARKADAŞIN YOK',
          message: 'Oyuncuları adıyla arayıp arkadaşlık isteği gönder.',
          actionLabel: 'OYUNCU ARA',
          onAction: () => setState(() => _sekme = _Sekme.search),
          scale: k,
        ),
      ];
    }
    return [
      for (final p in f) ...[
        V21PlayerRow(
          player: p,
          scale: k,
          trailing: V21IconPill(
            icon: Icons.person_remove_rounded,
            semanticsLabel: '${p.username}: arkadaşlıktan çıkar',
            scale: k * 0.8,
            onTap: () => _cikarOnay(context, vm, p),
          ),
        ),
        SizedBox(height: 8 * k),
      ],
    ];
  }

  Future<void> _cikarOnay(BuildContext context, FriendsViewModel vm, PlayerSummary p) async {
    final ok = await V21GameDialog.show<bool>(
      context,
      subtitle: 'ARKADAŞLIK',
      title: '${V21Format.upper(p.username)} ÇIKARILSIN MI?',
      message: 'Arkadaş listenden çıkar. İstersen sonra yeniden istek gönderebilirsin.',
      actions: const [
        V21DialogAction('ÇIKAR', tone: V21ButtonTone.red, result: true),
        V21DialogAction('VAZGEÇ', tone: V21ButtonTone.blue, result: false),
      ],
    );
    if (ok == true) await vm.remove(p);
  }

  List<Widget> _istekler(BuildContext context, FriendsViewModel vm, double k) {
    final gelen = vm.lists.incoming;
    final giden = vm.lists.outgoing;
    if (gelen.isEmpty && giden.isEmpty) {
      return [
        V21EmptyState(
          icon: Icons.mark_email_unread_rounded,
          title: 'İSTEK YOK',
          message: 'Sana gelen ve senin gönderdiğin arkadaşlık istekleri burada görünür.',
          scale: k,
        ),
      ];
    }
    return [
      if (gelen.isNotEmpty) ...[
        V21SectionTitle('GELEN İSTEKLER', trailing: '${gelen.length}', scale: k),
        for (final p in gelen) ...[
          V21PlayerRow(
            player: p,
            scale: k,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MiniButton('KABUL', V21ButtonTone.green, vm.isWorking(p.id), () => vm.accept(p), k),
                SizedBox(width: 6 * k),
                _MiniButton('REDDET', V21ButtonTone.red, vm.isWorking(p.id), () => vm.decline(p), k),
              ],
            ),
          ),
          SizedBox(height: 8 * k),
        ],
        SizedBox(height: 8 * k),
      ],
      if (giden.isNotEmpty) ...[
        V21SectionTitle('GÖNDERDİKLERİN', trailing: '${giden.length}', scale: k),
        for (final p in giden) ...[
          V21PlayerRow(
            player: p,
            scale: k,
            trailing: _MiniButton('GERİ ÇEK', V21ButtonTone.purple, vm.isWorking(p.id), () => vm.remove(p), k),
          ),
          SizedBox(height: 8 * k),
        ],
      ],
    ];
  }

  List<Widget> _ara(BuildContext context, FriendsViewModel vm, double k) => [
    V21SearchField(
      key: const Key('oyuncu-ara'),
      controller: _arama,
      hint: 'Oyuncu adı (en az 2 harf)',
      onChanged: vm.setQuery,
      scale: k,
    ),
    SizedBox(height: 12 * k),
    if (vm.searching)
      Center(
        child: Padding(
          padding: EdgeInsets.all(16 * k),
          child: const CircularProgressIndicator(color: V21Colors.goldTop),
        ),
      )
    else if (vm.query.length >= 2 && vm.results.isEmpty)
      V21EmptyState(
        icon: Icons.person_search_rounded,
        title: 'OYUNCU BULUNAMADI',
        message: '"${vm.query}" ile başlayan bir oyuncu yok.',
        scale: k,
      )
    else
      for (final p in vm.results) ...[
        V21PlayerRow(player: p, scale: k, trailing: _durumDugmesi(vm, p, k)),
        SizedBox(height: 8 * k),
      ],
  ];

  Widget _durumDugmesi(FriendsViewModel vm, PlayerSummary p, double k) {
    final mesgul = vm.isWorking(p.id);
    return switch (p.friendStatus) {
      FriendStatus.friends => V21Tag(text: 'ARKADAŞ', background: V21Colors.success, foreground: Colors.white, scale: k),
      FriendStatus.outgoing => V21Tag(text: 'İSTEK GİTTİ', background: V21Colors.ink, foreground: V21Colors.goldTop, scale: k),
      FriendStatus.incoming => _MiniButton('KABUL', V21ButtonTone.green, mesgul, () => vm.accept(p), k),
      FriendStatus.self => const SizedBox.shrink(),
      FriendStatus.none => _MiniButton('EKLE', V21ButtonTone.blue, mesgul, () => vm.sendRequest(p), k),
    };
  }
}

class _MiniButton extends StatelessWidget {
  final String label;
  final V21ButtonTone tone;
  final bool busy;
  final VoidCallback onPressed;
  final double scale;
  const _MiniButton(this.label, this.tone, this.busy, this.onPressed, this.scale);

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 84 * scale,
    child: V21GameButton(
      label: label,
      tone: tone,
      size: V21ButtonSize.small,
      scale: scale * 0.85,
      status: busy ? V21ButtonStatus.loading : V21ButtonStatus.normal,
      onPressed: onPressed,
    ),
  );
}

/// Basit arama kutusu (oyunun koyu mor stilinde)
class V21SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final double scale;
  const V21SearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.scale = 1,
  });

  @override
  Widget build(BuildContext context) {
    final k = scale;
    return Container(
      height: 46 * k,
      padding: EdgeInsets.symmetric(horizontal: 12 * k),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1150),
        borderRadius: BorderRadius.circular(14 * k),
        border: Border.all(color: V21Colors.ink, width: 2 * k),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: V21Colors.textMuted, size: 22 * k),
          SizedBox(width: 8 * k),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              maxLength: 20,
              textInputAction: TextInputAction.search,
              style: V21Type.label(15 * k, weight: FontWeight.w700, color: Colors.white),
              cursorColor: V21Colors.goldTop,
              decoration: InputDecoration(
                isDense: true,
                counterText: '',
                border: InputBorder.none,
                hintText: hint,
                hintStyle: V21Type.label(14 * k, weight: FontWeight.w600, color: V21Colors.textDim),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Oyuncu satırı: avatar (çevrimiçi noktası), ad, kupa + durum; dokununca profil
class V21PlayerRow extends StatelessWidget {
  final PlayerSummary player;
  final Widget? trailing;
  final double scale;
  const V21PlayerRow({super.key, required this.player, this.trailing, this.scale = 1});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final p = player;
    final durum = lastSeenText(p.online, p.lastSeenAt);
    return Semantics(
      button: true,
      label: '${p.username}, ${V21Format.thousands(p.mmr)} kupa, $durum. Profili aç',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push(AppRoutes.playerFor(p.id)),
        child: Container(
          padding: EdgeInsets.fromLTRB(10 * k, 8 * k, 10 * k, 8 * k),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14 * k),
            border: Border.all(color: V21Colors.ink, width: 2 * k),
            color: const Color(0xFF2E1675),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  V21PlayerAvatar(
                    seed: 'oyuncu-${p.id}',
                    semanticsLabel: p.username,
                    name: p.username,
                    size: 46 * k,
                    ringColor: const Color(0xFF8FC8FF),
                  ),
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 14 * k,
                      height: 14 * k,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: p.online ? V21Colors.success : const Color(0xFF6B5A9C),
                        border: Border.all(color: V21Colors.ink, width: 2 * k),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(width: 10 * k),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: V21Type.label(15 * k, weight: FontWeight.w900),
                    ),
                    SizedBox(height: 2 * k),
                    Row(
                      children: [
                        Icon(Icons.emoji_events_rounded, size: 14 * k, color: V21Colors.goldTop),
                        SizedBox(width: 3 * k),
                        Text(
                          V21Format.thousands(p.mmr),
                          style: V21Type.label(12 * k, weight: FontWeight.w800, color: V21Colors.goldTop),
                        ),
                        SizedBox(width: 8 * k),
                        Flexible(
                          child: Text(
                            durum,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: V21Type.label(
                              11 * k,
                              weight: FontWeight.w700,
                              color: p.online ? V21Colors.successText : V21Colors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[SizedBox(width: 6 * k), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// OYUNCU PROFİLİ (056) — herkes herkesin açık profilini görür
// =====================================================================

/// Başka bir oyuncunun açık profili.
///
/// GÖRÜNEN: ad, çerçeve/rozet, lig, kupa, G/M/B, kazanma oranı, son 5 maç,
/// koleksiyon ve arkadaş sayısı, en güçlü 3 kartı, katılma tarihi,
/// çevrimiçi durumu, aranızdaki maçlar. GİZLİ: e-posta, altın, elmas,
/// eşyalar, tam kadro.
class V21PlayerProfileScreen extends StatelessWidget {
  final String playerId;
  const V21PlayerProfileScreen({super.key, required this.playerId});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider<PlayerProfileViewModel>(
    create: (_) => PlayerProfileViewModel(
      getIt<SocialApi>(),
      playerId,
      session: getIt.isRegistered<SessionManager>() ? getIt<SessionManager>() : null,
    )..load(),
    child: const _ProfileBody(),
  );
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PlayerProfileViewModel>();
    final p = vm.profile;
    return V21InnerPage(
      title: 'OYUNCU',
      route: AppRoutes.player,
      fallbackRoute: AppRoutes.social,
      state: p == null ? (vm.isLoading ? V21PageState.loading : V21PageState.error) : V21PageState.ready,
      errorMessage: vm.error == null ? null : socialErrorText(vm.error!),
      onRetry: vm.load,
      onRefresh: vm.load,
      children: (context, k) {
        final pr = p!;
        return [
          _Kimlik(p: pr, scale: k),
          SizedBox(height: 12 * k),
          if (!vm.isSelf) ...[
            _ArkadaslikDugmesi(vm: vm, scale: k),
            if (vm.actionError != null)
              Padding(
                padding: EdgeInsets.only(top: 8 * k),
                child: Text(
                  vm.actionError!,
                  textAlign: TextAlign.center,
                  style: V21Type.label(13 * k, weight: FontWeight.w800, color: V21Colors.danger),
                ),
              ),
            SizedBox(height: 12 * k),
          ],
          Row(
            children: [
              Expanded(child: _Kutu(V21Format.thousands(pr.mmr), 'KUPA', const Color(0xFFFFD45E), k)),
              SizedBox(width: 8 * k),
              Expanded(child: _Kutu('${pr.totalMatches}', 'MAÇ', const Color(0xFF8FC8FF), k)),
              SizedBox(width: 8 * k),
              Expanded(
                child: _Kutu(
                  pr.totalMatches == 0 ? '—' : '%${(pr.winRate * 100).round()}',
                  'KAZANMA',
                  V21Colors.successText,
                  k,
                ),
              ),
            ],
          ),
          SizedBox(height: 8 * k),
          Row(
            children: [
              Expanded(child: _Kutu('${pr.collectionCount}', 'KART', const Color(0xFFE4B3FF), k)),
              SizedBox(width: 8 * k),
              Expanded(child: _Kutu('${pr.friendCount}', 'ARKADAŞ', const Color(0xFF8FC8FF), k)),
              SizedBox(width: 8 * k),
              Expanded(child: _Kutu('${pr.wins}G·${pr.losses}M', 'SONUÇ', Colors.white, k)),
            ],
          ),
          SizedBox(height: 16 * k),
          V21SectionTitle('SON MAÇLAR', scale: k),
          _Form(form: pr.recentForm, scale: k),
          if (!vm.isSelf && pr.headToHead.matches > 0) ...[
            SizedBox(height: 16 * k),
            V21SectionTitle('ARANIZDAKİ MAÇLAR', trailing: '${pr.headToHead.matches} MAÇ', scale: k),
            Text(
              'Sen ${pr.headToHead.myWins} · ${pr.username} ${pr.headToHead.theirWins} · Berabere ${pr.headToHead.draws}',
              style: V21Type.title(17 * k),
            ),
          ],
          SizedBox(height: 16 * k),
          V21SectionTitle('EN GÜÇLÜ KARTLARI', scale: k),
          if (pr.topCards.isEmpty)
            Text('Henüz kartı yok.', style: V21Type.label(13 * k, weight: FontWeight.w600, color: V21Colors.textMuted))
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final c in pr.topCards)
                  V21PlayerCard(name: c.fullName, position: c.position, tier: c.tier, power: c.power, width: 100 * k),
              ],
            ),
          SizedBox(height: 16 * k),
          if (pr.joinedAt != null)
            Text(
              'Katılma: ${_tarih(pr.joinedAt!)}',
              textAlign: TextAlign.center,
              style: V21Type.label(12 * k, weight: FontWeight.w600, color: V21Colors.textDim),
            ),
        ];
      },
    );
  }

  static String _tarih(DateTime d) {
    const aylar = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
    return '${d.day} ${aylar[d.month - 1]} ${d.year}';
  }
}

class _Kimlik extends StatelessWidget {
  final PublicProfile p;
  final double scale;
  const _Kimlik({required this.p, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final r = p.rank;
    final avatar = V21PlayerAvatar(
      seed: 'oyuncu-${p.id}',
      semanticsLabel: 'Avatar',
      name: p.username,
      size: 96 * k,
      ringColor: const Color(0xFFFFC832),
      background: const Color(0xFF5FB4FF),
    );
    return Container(
      padding: EdgeInsets.fromLTRB(14 * k, 14 * k, 14 * k, 14 * k),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18 * k),
        border: Border.all(color: V21Colors.ink, width: 3 * k),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4A2BA8), Color(0xFF2E1675)],
        ),
      ),
      child: Row(
        children: [
          CosmeticFrame(slug: p.frame, size: 96 * k, child: avatar),
          SizedBox(width: 14 * k),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(p.username, style: V21Type.title(26 * k, shadows: V21Type.inkShadow(k))),
                ),
                SizedBox(height: 6 * k),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12 * k, vertical: 3 * k),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20 * k),
                    border: Border.all(color: V21Colors.ink, width: 2 * k),
                    gradient: const LinearGradient(colors: [Color(0xFFFFE27A), Color(0xFFE0A030)]),
                  ),
                  child: Text(
                    r == null ? 'LİG' : V21Format.upper(r.label),
                    style: V21Type.title(15 * k, color: const Color(0xFF3A1E00)),
                  ),
                ),
                SizedBox(height: 8 * k),
                Row(
                  children: [
                    Container(
                      width: 10 * k,
                      height: 10 * k,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: p.online ? V21Colors.success : const Color(0xFF6B5A9C),
                      ),
                    ),
                    SizedBox(width: 6 * k),
                    Text(
                      lastSeenText(p.online, p.lastSeenAt),
                      style: V21Type.label(
                        12 * k,
                        weight: FontWeight.w800,
                        color: p.online ? V21Colors.successText : V21Colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArkadaslikDugmesi extends StatelessWidget {
  final PlayerProfileViewModel vm;
  final double scale;
  const _ArkadaslikDugmesi({required this.vm, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final s = vm.profile!.friendStatus;
    final durum = vm.acting ? V21ButtonStatus.loading : V21ButtonStatus.normal;
    Widget dugme(String label, V21ButtonTone tone, VoidCallback f) => V21GameButton(
      label: label,
      tone: tone,
      size: V21ButtonSize.medium,
      scale: k,
      status: durum,
      onPressed: f,
    );
    return switch (s) {
      FriendStatus.none => dugme('ARKADAŞ EKLE', V21ButtonTone.green, vm.addFriend),
      FriendStatus.outgoing => dugme('İSTEĞİ GERİ ÇEK', V21ButtonTone.purple, vm.removeFriend),
      FriendStatus.incoming => Row(
        children: [
          Expanded(child: dugme('KABUL ET', V21ButtonTone.green, vm.accept)),
          SizedBox(width: 8 * k),
          Expanded(child: dugme('REDDET', V21ButtonTone.red, vm.decline)),
        ],
      ),
      FriendStatus.friends => dugme('ARKADAŞSINIZ · ÇIKAR', V21ButtonTone.purple, () async {
        final ok = await V21GameDialog.show<bool>(
          context,
          subtitle: 'ARKADAŞLIK',
          title: 'ARKADAŞLIKTAN ÇIKAR?',
          message: '${vm.profile!.username} arkadaş listenden çıkar.',
          actions: const [
            V21DialogAction('ÇIKAR', tone: V21ButtonTone.red, result: true),
            V21DialogAction('VAZGEÇ', tone: V21ButtonTone.blue, result: false),
          ],
        );
        if (ok == true) await vm.removeFriend();
      }),
      FriendStatus.self => const SizedBox.shrink(),
    };
  }
}

class _Kutu extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final double scale;
  const _Kutu(this.value, this.label, this.color, this.scale);

  @override
  Widget build(BuildContext context) {
    final k = scale;
    return Semantics(
      label: '$label $value',
      excludeSemantics: true,
      child: V21GamePanel(
        scale: k,
        radius: 14,
        padding: EdgeInsets.symmetric(vertical: 10 * k, horizontal: 6 * k),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: V21Type.title(22 * k, color: color, shadows: V21Type.inkShadow(k))),
            ),
            SizedBox(height: 2 * k),
            Text(label, style: V21Type.label(11 * k, weight: FontWeight.w800, color: V21Colors.textMuted)),
          ],
        ),
      ),
    );
  }
}

/// Son maçların G/M/B rozetleri (en yeni solda)
class _Form extends StatelessWidget {
  final List<String> form;
  final double scale;
  const _Form({required this.form, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    if (form.isEmpty) {
      return Text(
        'Henüz dereceli maç oynamadı.',
        style: V21Type.label(13 * k, weight: FontWeight.w600, color: V21Colors.textMuted),
      );
    }
    return Semantics(
      label: 'Son maçlar: ${form.map(_ad).join(', ')}',
      excludeSemantics: true,
      child: Row(
        children: [
          for (final f in form) ...[
            Container(
              width: 38 * k,
              height: 38 * k,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10 * k),
                border: Border.all(color: V21Colors.ink, width: 2 * k),
                color: switch (f) {
                  'win' => V21Colors.success,
                  'loss' => V21Colors.danger,
                  _ => V21Colors.goldBottom,
                },
              ),
              child: Text(switch (f) {
                'win' => 'G',
                'loss' => 'M',
                _ => 'B',
              }, style: V21Type.title(18 * k)),
            ),
            SizedBox(width: 6 * k),
          ],
        ],
      ),
    );
  }

  static String _ad(String f) => switch (f) {
    'win' => 'galibiyet',
    'loss' => 'mağlubiyet',
    _ => 'beraberlik',
  };
}

// =====================================================================
// RAKİP KADROSU (056) — son maçlar listesinden
// =====================================================================

/// Bitmiş maçta rakibin oynadığı 11 kart, sahadaki gibi dizilmiş.
class V21OpponentSquadSheet extends StatelessWidget {
  final String matchId;
  const V21OpponentSquadSheet({super.key, required this.matchId});

  static Future<void> show(BuildContext context, String matchId) => showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Kapat',
    barrierColor: const Color(0xCC120933),
    pageBuilder: (_, _, _) => V21OpponentSquadSheet(matchId: matchId),
  );

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider<OpponentSquadViewModel>(
    create: (_) => OpponentSquadViewModel(getIt<SocialApi>(), matchId)..load(),
    child: const _SquadBody(),
  );
}

class _SquadBody extends StatelessWidget {
  const _SquadBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OpponentSquadViewModel>();
    final s = vm.squad;
    final k = (MediaQuery.sizeOf(context).width / 390).clamp(0.8, 1.2);
    Widget icerik;
    if (s == null) {
      icerik = vm.isLoading || vm.error == null
          ? const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator(color: V21Colors.goldTop)),
            )
          : Padding(
              padding: EdgeInsets.all(20 * k),
              child: Text(
                vm.errorText ?? 'Kadro yüklenemedi.',
                textAlign: TextAlign.center,
                style: V21Type.label(14 * k, weight: FontWeight.w800, color: V21Colors.danger),
              ),
            );
    } else {
      final cw = 64.0 * k;
      Widget satir(CardPosition p) => Padding(
        padding: EdgeInsets.symmetric(vertical: 4 * k),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 6 * k,
          runSpacing: 6 * k,
          children: [
            for (final c in s.byPosition(p))
              V21PlayerCard(name: c.fullName, position: c.position, tier: c.tier, power: c.power, width: cw),
          ],
        ),
      );
      final sonuc = switch (s.outcome) {
        'win' => ('KAZANDIN', V21Colors.success),
        'loss' => ('KAYBETTİN', V21Colors.danger),
        _ => ('BERABERE', V21Colors.goldBottom),
      };
      icerik = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('RAKİBİN KADROSU', style: V21Type.label(12 * k, weight: FontWeight.w800, color: V21Colors.textMuted)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(V21Format.upper(s.opponentUsername), style: V21Type.title(24 * k)),
                    ),
                  ],
                ),
              ),
              V21Tag(text: sonuc.$1, background: sonuc.$2, foreground: Colors.white, scale: k),
            ],
          ),
          SizedBox(height: 4 * k),
          Text(
            '${s.cards.length} kart · ortalama güç ${s.averagePower} · ${V21Format.thousands(s.opponentMmr)} kupa',
            style: V21Type.label(12 * k, weight: FontWeight.w700, color: V21Colors.goldTop),
          ),
          SizedBox(height: 10 * k),
          Container(
            padding: EdgeInsets.symmetric(vertical: 8 * k, horizontal: 4 * k),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16 * k),
              border: Border.all(color: V21Colors.ink, width: 3 * k),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF3DB45A), Color(0xFF1E7A35)],
              ),
            ),
            child: Column(
              children: [
                satir(CardPosition.forward),
                satir(CardPosition.midfielder),
                satir(CardPosition.defender),
                satir(CardPosition.goalkeeper),
              ],
            ),
          ),
          SizedBox(height: 12 * k),
          Row(
            children: [
              if (s.opponentId.isNotEmpty) ...[
                Expanded(
                  child: V21GameButton(
                    label: 'PROFİLİ',
                    tone: V21ButtonTone.blue,
                    size: V21ButtonSize.small,
                    scale: k,
                    onPressed: () {
                      Navigator.of(context).pop();
                      GoRouter.maybeOf(context)?.push(AppRoutes.playerFor(s.opponentId));
                    },
                  ),
                ),
                SizedBox(width: 8 * k),
              ],
              Expanded(
                child: V21GameButton(
                  label: 'KAPAT',
                  tone: V21ButtonTone.purple,
                  size: V21ButtonSize.small,
                  scale: k,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ],
      );
    }
    return SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(14 * k),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: EdgeInsets.all(14 * k),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22 * k),
                  border: Border.all(color: V21Colors.ink, width: 4 * k),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF4A2BA8), Color(0xFF241060)],
                  ),
                ),
                child: SingleChildScrollView(child: icerik),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


// =====================================================================
// MAĞAZA: ELMASLA ALTIN (056)
// =====================================================================

/// Mağazadaki elmas bölümü: bakiye + 3 altın paketi. Elmas sandıklardan
/// kazanılır; gerçek para ile satış yok.
class V21GemStoreSection extends StatelessWidget {
  final double scale;
  const V21GemStoreSection({super.key, this.scale = 1});

  @override
  Widget build(BuildContext context) {
    if (!getIt.isRegistered<SocialApi>()) return const SizedBox.shrink();
    return ChangeNotifierProvider<GemStoreViewModel>(
      create: (_) => GemStoreViewModel(
        getIt<SocialApi>(),
        session: getIt.isRegistered<SessionManager>() ? getIt<SessionManager>() : null,
      )..load(),
      child: _GemStoreBody(scale: scale),
    );
  }
}

class _GemStoreBody extends StatelessWidget {
  final double scale;
  const _GemStoreBody({required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final vm = context.watch<GemStoreViewModel>();
    final teklifler = vm.status?.exchange ?? const <GemOffer>[];
    return Column(
      key: const Key('elmas-bolumu'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('ELMASLA ALTIN', style: V21Type.title(24 * k, shadows: V21Type.inkShadow(k)))),
            V21ResourcePill.gems(gems: vm.gems, scale: k),
          ],
        ),
        SizedBox(height: 4 * k),
        Text(
          'Elmas sandıklardan çıkar. Sandığı beklemeden açmak ya da altın almak için kullan.',
          style: V21Type.label(12 * k, weight: FontWeight.w600, color: V21Colors.textMuted, height: 1.35),
        ),
        SizedBox(height: 10 * k),
        if (teklifler.isEmpty)
          const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(color: V21Colors.goldTop)))
        else
          Row(
            children: [
              for (final o in teklifler) ...[
                if (o != teklifler.first) SizedBox(width: 8 * k),
                Expanded(child: _GemOfferCard(offer: o, vm: vm, scale: k)),
              ],
            ],
          ),
        if (vm.actionError != null || vm.info != null) ...[
          SizedBox(height: 8 * k),
          Text(
            vm.actionError ?? vm.info!,
            textAlign: TextAlign.center,
            style: V21Type.label(
              13 * k,
              weight: FontWeight.w800,
              color: vm.actionError != null ? V21Colors.danger : V21Colors.successText,
            ),
          ),
        ],
      ],
    );
  }
}

class _GemOfferCard extends StatelessWidget {
  final GemOffer offer;
  final GemStoreViewModel vm;
  final double scale;
  const _GemOfferCard({required this.offer, required this.vm, required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final o = offer;
    final yeter = vm.canBuy(o);
    return Container(
      padding: EdgeInsets.fromLTRB(6 * k, 10 * k, 6 * k, 8 * k),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16 * k),
        border: Border.all(color: V21Colors.ink, width: 3 * k),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4A2BA8), Color(0xFF2E1675)],
        ),
      ),
      child: Column(
        children: [
          V21CoinIcon(size: 40 * k),
          SizedBox(height: 4 * k),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(V21Format.thousands(o.coins), style: V21Type.title(22 * k, color: V21Colors.goldTop)),
          ),
          Text('ALTIN', style: V21Type.label(11 * k, weight: FontWeight.w800, color: V21Colors.textMuted)),
          SizedBox(height: 8 * k),
          V21GameButton(
            key: Key('elmas-${o.slug}'),
            label: '${o.gems} ELMAS',
            tone: yeter ? V21ButtonTone.green : V21ButtonTone.purple,
            size: V21ButtonSize.small,
            scale: k,
            status: vm.busyOffer == o.slug ? V21ButtonStatus.loading : V21ButtonStatus.normal,
            semanticsLabel: '${o.gems} elmasa ${o.coins} altın al',
            onPressed: () => vm.buy(o),
          ),
        ],
      ),
    );
  }
}

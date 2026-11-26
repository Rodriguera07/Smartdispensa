# 🌿 Smart Dispensa

Aplicativo Android em **Flutter (Material 3)** para controle inteligente da despensa doméstica,
com **scanner de notas fiscais por OCR offline**, **lista de compras inteligente** e modelo
**Freemium** com assinaturas via Google Play Billing, tudo com **custo de infraestrutura R$ 0**.

| Camada | Tecnologia | Custo |
|---|---|---|
| Autenticação | Firebase Auth (e-mail/senha + Google) | Grátis (plano Spark) |
| Banco de dados | Cloud Firestore + persistência offline | Grátis (plano Spark) |
| OCR | Google ML Kit Text Recognition (no aparelho) | Grátis, sem API paga |
| Assinaturas | RevenueCat (Free até US$ 2.500/mês) + Google Play Billing | Grátis |

---

## ✨ Funcionalidades

- **Splash, Login e Cadastro**: e-mail/senha, Google e recuperação de senha.
- **Dashboard "Início"**: cards em Glassmorphism (*Total na Despensa*, *Acabando / Em Falta*,
  *Gasto no Mês*), busca, filtro por categoria e barras de nível de estoque.
  - **Usar (-1)**: quando o item zera, o app pergunta se deve ir para a lista (ou envia direto,
    se o usuário marcar "Sempre enviar automaticamente").
  - **Adicionar à Lista** com 1 toque.
- **Scanner de Nota Fiscal**: câmera ou galeria, OCR local e regex próprias para cupons brasileiros
  (NFC-e, SAT, supermercados e atacarejos). Depois vem a **Pré-Validação**, onde o usuário edita nome,
  quantidade, preço e categoria antes de salvar.
- **Lista de Compras**: itens que acabaram entram sozinhos, adição manual rápida, **ordenação por
  corredor**, **sugestões inteligentes** (itens recorrentes do histórico), **compartilhar no
  WhatsApp** com emojis por categoria e **Finalizar Compra**, que devolve os itens ao estoque e
  atualiza o gasto do mês.
- **Relatórios (Premium)**: mensal/quinzenal, gastos por categoria, comparação com o período anterior,
  itens que mais pesaram e variação de preços.
- **Histórico de preços por produto (Premium)** com gráfico.
- **Paywall**: comparativo Grátis × Premium, planos Mensal R$ 5,90, Trimestral R$ 14,90
  (*Mais Popular 🔥*) e Anual R$ 49,90 (*Melhor Oferta 👑*), CTA **"Começar 7 Dias Grátis"** e
  aviso claro do valor cobrado depois do teste.
- **Perfil**: tema escuro/claro, envio automático à lista, restaurar compras e sair.

### Plano Grátis × Premium

| Recurso | Grátis | Premium ✨ |
|---|---|---|
| Escaneamento de notas | 3 por mês | Ilimitado |
| Estoque manual | Ilimitado | Ilimitado |
| Lista de compras inteligente | ✓ | ✓ |
| Histórico de variação de preços | — | ✓ |
| Relatórios mensais/quinzenais | — | ✓ |
| Sem anúncios | — | ✓ |

---

## 🏗️ Arquitetura

```text
lib/
├── main.dart                     # Bootstrap: Firebase, persistência offline, locale pt_BR
├── app.dart                      # MaterialApp, árvore de Providers, AuthGate
├── core/
│   ├── constants/app_constants.dart
│   ├── theme/app_colors.dart     # Paleta "Fresh Tech & Glass"
│   ├── theme/app_theme.dart      # ThemeData M3 claro/escuro, Plus Jakarta Sans + Inter
│   └── utils/formatters.dart     # R$, quantidades, datas, normalização de texto
├── models/                       # PantryItem, ShoppingItem, PurchaseRecord, ReceiptItem,
│                                 # UserProfile, ItemCategory (+ classificador por palavras-chave)
├── services/
│   ├── firebase_service.dart     # Auth + Firestore (escritas offline-first)
│   ├── ocr_service.dart          # image_picker + ML Kit + parsing em Isolate
│   ├── receipt_parser.dart       # Regex de cupons fiscais (Dart puro, testado)
│   └── subscription_service.dart # RevenueCat / Google Play Billing
├── viewmodels/                   # ChangeNotifiers (provider)
│   ├── auth_viewmodel.dart       ├── pantry_viewmodel.dart
│   ├── user_viewmodel.dart       ├── shopping_list_viewmodel.dart
│   ├── subscription_viewmodel.dart ├── scanner_viewmodel.dart
│   ├── theme_viewmodel.dart      └── reports_viewmodel.dart
├── views/                        # splash, auth, home, pantry, scanner, shopping,
│                                 # paywall, reports, profile
└── widgets/                      # GlassCard, GradientBackground, GlowButton, ScanGlowFab,
                                  # StockLevelBar, PremiumBadge, CategoryDropdown...
```

**Fluxo de dados:** `View → ViewModel (ChangeNotifier) → Service → Firebase/ML Kit/RevenueCat`.
Os ViewModels da sessão são criados no login (chave = `uid`) e descartados no logout, o que também
encerra os listeners do Firestore.

### Decisões de performance
- **`BackdropFilter` só em elementos de destaque.** Itens de lista usam "vidro leve" (`GlassCard(blur: false)`),
  porque o desfoque real em cada linha derrubaria a rolagem abaixo de 60 fps.
- **`SliverList.builder` / `ListView.builder`**: só o que está visível na tela é construído.
- **OCR fora da UI.** O ML Kit roda em thread nativa e o parsing por regex roda em `Isolate.run`.
- **Valores derivados em cache.** Totais, agrupamentos e sugestões são recalculados uma vez por
  atualização do Firestore, e não a cada `build`.
- **`RepaintBoundary`** no fundo em gradiente e no FAB animado. O FAB respeita "reduzir animações".

### Offline-first
A persistência do Firestore fica ativa com cache ilimitado. As **escritas não são aguardadas**: o SDK
grava no cache local na hora, a UI atualiza imediatamente e a sincronização acontece sozinha quando a
internet volta. Dá para usar a lista inteira dentro do supermercado sem sinal.

### Modelo de dados (Firestore)
```text
users/{uid}                     name, email, darkMode, autoSendToList, scanPeriod, scanCount
users/{uid}/pantry/{id}         name, normalizedName, category, quantity, idealQuantity, unit, lastPrice
users/{uid}/shopping_list/{id}  name, category, quantity, unit, checked, price, pantryItemId, autoAdded
users/{uid}/purchases/{id}      name, normalizedName, category, quantity, unitPrice, total, date, source, store
```
As regras de segurança estão em [`firestore.rules`](firestore.rules): cada usuário só acessa os próprios dados
e o histórico de compras não pode ser alterado.

---

## 🚀 Como rodar

### 1. Pré-requisitos
- Flutter **3.50+** (Dart 3.14+). Nesta versão o Material vem do pacote `material_ui`.
- Android SDK com um aparelho ou emulador com **API 23+**.

```bash
flutter pub get
```

### 2. Firebase (plano Spark, gratuito)
1. Crie um projeto no [Console do Firebase](https://console.firebase.google.com) e adicione um app Android
   com o pacote **`br.com.smartdispensa.smart_dispensa`**.
2. Baixe o **`google-services.json`** e coloque em `android/app/`. O arquivo está no `.gitignore`.
   Sem ele o app abre uma tela explicando o que falta.
3. Em **Authentication → Sign-in method**, ative **E-mail/senha** e **Google**.
4. Cadastre as impressões digitais **SHA-1 e SHA-256** (necessárias para o login com Google):
   ```bash
   cd android && ./gradlew signingReport
   ```
5. Crie o **Cloud Firestore** e publique as regras:
   ```bash
   firebase deploy --only firestore:rules
   ```

### 3. RevenueCat + Google Play (assinaturas)
1. No **Google Play Console**, crie três assinaturas com plano base e uma **oferta de teste grátis
   de 7 dias** (`P1W`) em cada uma:
   - Mensal: **R$ 5,90**
   - Trimestral: **R$ 14,90**
   - Anual: **R$ 49,90**
2. No **RevenueCat**, conecte o app Android, crie o entitlement **`premium`** e a offering *current* com os
   pacotes padrão `$rc_monthly`, `$rc_three_month` e `$rc_annual`, ligados aos produtos acima.
3. Rode o app passando a chave pública do SDK Android (ela não é commitada):
   ```bash
   flutter run --dart-define=REVENUECAT_ANDROID_KEY=goog_xxxxxxxxxxxxx
   ```
   Sem a chave, o app funciona normalmente no plano Grátis e o paywall mostra os preços de referência.

> Para testar compras, envie o app para uma faixa de **teste interno** no Play Console e use uma conta
> de *license tester*.

### 4. Testes
```bash
flutter analyze
flutter test
```
São 21 testes, cobrindo:
- o parser de cupons (linha única, unidade antes da quantidade, itens a granel, atacarejo em 2 linhas,
  correção de "O"→"0" e reconstrução de colunas do OCR);
- relatórios, categorias e formatação;
- teste de fumaça do paywall, incluindo tela pequena com fonte ampliada.

---

## 🎨 Design System, "Fresh Tech & Glass"

| Token | Cor | Uso |
|---|---|---|
| Azul-Petróleo | `#0B192C` | Início do gradiente escuro |
| Verde-Esmeralda Escuro | `#0F292E` | Fim do gradiente escuro |
| Fundo claro | `#F4F7F9` | Variante clara |
| Verde-Menta | `#00D09C` | Cor primária / ações |
| Ciano Elétrico | `#00B4D8` | Acentos e badges |
| Dourado Suave | `#F5B700` | Exclusivo do Premium ✨ |

- **Tipografia:** Plus Jakarta Sans nos títulos e Inter nos dados (via `google_fonts`).
- **Acessibilidade:** botões com no mínimo 56 dp, corpo de texto ≥ 15–17 sp, rótulos de leitor de
  tela (`Semantics`), layout que se adapta a fontes grandes e cores com alto contraste.

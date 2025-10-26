# Relatório - Laboratório 2: Interface Profissional

**Laboratório de Desenvolvimento de Aplicações Móveis e Distribuídas**  
**Curso de Engenharia de Software - PUC Minas**  
**Data:** 26 de Outubro de 2025  
**Aluno:** Roberta Sophia Carvalho Silva

---

## 1. Implementações Realizadas

### 1.1 Funcionalidades Básicas do Roteiro
- **Tela de Formulário Separada**: Criação da `TaskFormScreen` com navegação completa entre telas
- **Navegação Push/Pop**: Implementação correta do stack de navegação do Flutter
- **Validação de Formulários**: Validação em tempo real com `GlobalKey<FormState>`
- **Widget TaskCard Customizado**: Card personalizado com visual profissional
- **Sistema de Filtros**: Filtros para "Todas", "Pendentes" e "Concluídas"
- **Card de Estatísticas**: Dashboard visual com contadores dinâmicos
- **Estados Vazios**: Mensagens contextuais quando não há dados
- **Pull-to-Refresh**: Atualização da lista por gesto
- **Dialogs de Confirmação**: Confirmação antes de deletar tarefas
- **SnackBars de Feedback**: Notificações de sucesso e erro

### 1.2 Componentes Material Design 3 Utilizados
- **Cards Elevados**: Com bordas arredondadas e sombras apropriadas
- **FloatingActionButton Extended**: Com ícone e texto
- **TextFormField**: Com outline border e ícones prefixados
- **DropdownButtonFormField**: Para seleção de prioridade
- **SwitchListTile**: Para status de conclusão
- **PopupMenuButton**: Para filtros e ordenação
- **AlertDialog**: Para confirmações
- **SnackBar**: Para feedback imediato
- **InkWell**: Para efeitos de toque nos cards
- **InputDecorator**: Para campos customizados
- **CircularProgressIndicator**: Para estados de loading

### 1.3 Arquitetura Implementada
```
lib/
├── main.dart (configuração do app)
├── models/
│   └── task.dart (modelo de dados com dueDate)
├── services/
│   └── database_service.dart (SQLite com migração)
├── screens/
│   ├── task_list_screen.dart (lista principal)
│   └── task_form_screen.dart (formulário CRUD)
└── widgets/
    └── task_card.dart (componente reutilizável)
```

---

## 2. Desafios Encontrados

### 2.1 Migração do Banco de Dados
**Dificuldade:** Adicionar a nova coluna `dueDate` sem perder dados existentes.

**Solução:** Implementei um sistema de versionamento do banco:
```dart
Future<Database> _initDB(String filePath) async {
  return await openDatabase(
    path,
    version: 2, // Atualizado de 1 para 2
    onCreate: _createDB,
    onUpgrade: _upgradeDB, // Adicionado método de upgrade
  );
}

Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    await db.execute('ALTER TABLE tasks ADD COLUMN dueDate TEXT');
  }
}
```

### 2.2 Gerenciamento de Estado Complexo
**Dificuldade:** Sincronizar filtros, ordenação e busca simultaneamente.

**Solução:** Criei um getter computado `_filteredTasks` que aplica todas as transformações:
```dart
List<Task> get _filteredTasks {
  var tasks = _tasks;
  
  // Aplicar filtros por status
  switch (_filter) {
    case 'completed': tasks = tasks.where((t) => t.completed).toList();
    case 'pending': tasks = tasks.where((t) => !t.completed).toList();
    case 'overdue': tasks = tasks.where((t) => t.isOverdue).toList();
  }
  
  // Aplicar busca por texto
  if (_searchQuery.isNotEmpty) {
    tasks = tasks.where((t) => 
      t.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      t.description.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }
  
  // Aplicar ordenação
  switch (_sortBy) {
    case 'dueDate': /* ordenação customizada */
    case 'priority': /* ordenação por prioridade */
    default: /* ordenação padrão */
  }
  
  return tasks;
}
```

### 2.3 DatePicker e Validação de Datas
**Dificuldade:** Implementar seletor de data com validações apropriadas.

**Solução:** Utilizei `InputDecorator` com `InkWell` para criar um campo customizado:
```dart
InkWell(
  onTap: _selectDueDate,
  child: InputDecorator(
    decoration: const InputDecoration(
      labelText: 'Data de Vencimento',
      prefixIcon: Icon(Icons.calendar_today),
    ),
    child: Text(/* formatação da data */),
  ),
)
```

---

## 3. Melhorias Implementadas

### 3.1 **PRINCIPAL MELHORIA: Sistema de Data de Vencimento**

Implementei completamente o **Exercício 1 - Data de Vencimento** do roteiro, que inclui:

#### 3.1.1 Modelo de Dados Expandido
```dart
class Task {
  final DateTime? dueDate; // ← NOVO CAMPO
  
  // Métodos auxiliares implementados:
  bool get isOverdue => /* lógica de vencimento */
  bool get isDueToday => /* lógica para hoje */
  bool get isDueSoon => /* lógica para próximos dias */
}
```

#### 3.1.2 Interface de Seleção de Data
- **DatePicker integrado** no formulário
- **Indicadores visuais** de status da data (vencida/hoje/em breve)
- **Validação automática** (não permite datas passadas)
- **Botão para remover** data de vencimento

#### 3.1.3 Alertas Visuais Inteligentes
- **Card de alerta vermelho** na tela principal para tarefas vencidas
- **Cores dinâmicas** nos cards baseadas na urgência:
  - Vermelho: Tarefas vencidas
  - Laranja: Vencem hoje
  - Amarelo: Vencem em breve (3 dias)
  - Verde: Prazo tranquilo

#### 3.1.4 Filtros e Ordenação Avançados
- **Novo filtro "Vencidas"** no menu principal
- **Ordenação por data de vencimento** (mais urgentes primeiro)
- **Algoritmo inteligente** que coloca tarefas sem prazo no final

### 3.2 Funcionalidade de Busca
Implementei busca em tempo real que funciona em conjunto com filtros:
```dart
// Busca por título e descrição simultaneamente
if (_searchQuery.isNotEmpty) {
  tasks = tasks.where((t) {
    return t.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
           t.description.toLowerCase().contains(_searchQuery.toLowerCase());
  }).toList();
}
```

### 3.3 Melhorias de UX
- **Estados vazios contextuais** para cada filtro
- **Indicadores de loading** em todas as operações assíncronas
- **Feedback visual imediato** com SnackBars coloridos
- **Área de toque otimizada** (mínimo 48x48px)

---

## 4. Aprendizados

### 4.1 Principais Conceitos Aprendidos

#### Material Design 3
- Compreendi os princípios de **Material You** com cores dinâmicas
- Aprendi a usar **ColorScheme.fromSeed()** para temas consistentes
- Dominei o uso de **elevation** e **shape** para hierarquia visual

#### Navegação no Flutter
- Entendi o conceito de **Stack de Navegação**
- Implementei **Navigator.push()** e **Navigator.pop()** corretamente
- Aprendi a passar dados entre telas e capturar resultados

#### Gerenciamento de Estado
- Dominei o uso de **StatefulWidget** para estado local
- Entendi quando usar **setState()** vs **mounted** para evitar memory leaks
- Aprendi padrões de **lifting state up** para comunicação entre widgets

#### Banco de Dados SQLite
- Implementei **migrações de schema** sem perda de dados
- Aprendi **queries avançadas** com ORDER BY e WHERE complexos
- Entendi **transações** e **operações assíncronas**

### 4.2 Diferenças entre Lab 1 e Lab 2

| Aspecto | Laboratório 1 | Laboratório 2 |
|---------|---------------|---------------|
| **Arquitetura** | Monolítica (1 arquivo) | Modular (5+ arquivos) |
| **Interface** | ListTile simples | Cards Material Design 3 |
| **Navegação** | Nenhuma | Push/Pop entre 2 telas |
| **Validação** | Básica inline | FormKey com validators |
| **Estado** | Local simples | Gerenciamento complexo |
| **Feedback** | Nenhum | SnackBars + Dialogs |
| **Funcionalidades** | CRUD básico | CRUD + Filtros + Busca + Datas |
| **UX** | Funcional | Profissional |

### 4.3 Padrões de Desenvolvimento
- **Single Responsibility**: Cada widget tem uma função específica
- **Composition over Inheritance**: Uso de widgets componíveis
- **Separation of Concerns**: Modelo, View e Service separados
- **Error Handling**: Try-catch com feedback ao usuário
- **Defensive Programming**: Verificações de `mounted` e validações

---

## 5. Próximos Passos

### 5.1 Melhorias Técnicas Identificadas
1. **Implementar Provider/Bloc** para gerenciamento de estado mais robusto
2. **Adicionar testes unitários** para validar regras de negócio
3. **Implementar CI/CD** com GitHub Actions
4. **Adicionar análise de código** com custom lint rules

### 5.2 Funcionalidades Futuras
1. **Sistema de Categorias** (Exercício 2)
   - Modelo Category com cores customizadas
   - Filtro por categoria
   - Organização visual por grupos

2. **Notificações Locais** (Exercício 3)
   - Lembretes baseados em data de vencimento
   - Notificações push para tarefas urgentes
   - Configurações de frequência

3. **Compartilhamento** (Exercício 4)
   - Compartilhar tarefas via apps nativos
   - Export para formatos populares (CSV, JSON)
   - Sincronização com serviços externos

4. **Melhorias de UX**
   - **Tema escuro/claro** automático
   - **Animations** nas transições
   - **Drag & Drop** para reordenar tarefas
   - **Swipe actions** nos cards

### 5.3 Otimizações de Performance
- **Lazy loading** para listas grandes
- **Debounce** na busca em tempo real
- **Caching** de queries frequentes
- **Índices de banco** otimizados

---

## 6. Conclusão

A implementação da **funcionalidade de Data de Vencimento** como melhoria principal demonstrou:

### **Objetivos Alcançados:**
- Interface profissional seguindo Material Design 3
- Navegação fluida entre múltiplas telas
- Formulários robustos com validação completa
- Sistema inteligente de alertas e priorização
- Arquitetura escalável e bem organizada

### **Impacto da Melhoria:**
A funcionalidade de data de vencimento transformou um simples gerenciador de tarefas em uma **ferramenta de produtividade real**, com:
- Alertas visuais automáticos
- Priorização inteligente por urgência
- Experiência de usuário profissional
- Funcionalidades comparáveis a apps comerciais

### **Aprendizado Técnico:**
- Domínio completo do desenvolvimento Flutter
- Padrões de arquitetura limpa
- Gerenciamento de estado eficiente
- Integração banco de dados avançada
- Princípios de UX/UI mobile

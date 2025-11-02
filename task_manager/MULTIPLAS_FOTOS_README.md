# Funcionalidade Múltiplas Fotos - Lab 4

## Visão Geral
Esta funcionalidade estende o aplicativo de gerenciamento de tarefas para suportar múltiplas fotos por tarefa, além da funcionalidade de foto única existente do Lab 3.

## Funcionalidades Implementadas

### 1. Modelo de Dados (Task)
- ✅ Adicionado campo `photoPaths` (List<String>) para múltiplas fotos
- ✅ Mantida compatibilidade com campo `photoPath` existente
- ✅ Novos métodos utilitários:
  - `hasMultiplePhotos`: verifica se a tarefa tem mais de uma foto
  - `photoCount`: retorna o número total de fotos
  - `allPhotoPaths`: retorna todas as fotos (combina photoPath e photoPaths)

### 2. Banco de Dados
- ✅ Atualizado esquema para versão 5
- ✅ Adicionada coluna `photoPaths` (TEXT)
- ✅ Implementada migração automática preservando dados existentes
- ✅ Compatibilidade com dados antigos do Lab 3

### 3. Serviço de Câmera (CameraService)
- ✅ `pickMultipleImagesFromGallery()`: seleção múltipla da galeria
- ✅ `showMultiImageSourceDialog()`: diálogo aprimorado com opções:
  - 📷 Câmera (uma foto)
  - 🖼️ Galeria - Uma foto
  - 📷📷 Galeria - Múltiplas fotos
- ✅ `deleteMultiplePhotos()`: exclusão em lote

### 4. Widget de Galeria (PhotoGalleryWidget)
- ✅ Exibição em grade de múltiplas fotos
- ✅ Visualização em tela cheia com navegação por swipe
- ✅ Botões de exclusão individual (modo edição)
- ✅ Contador de fotos
- ✅ Altura configurável ou total da tela

### 5. Tela de Formulário (TaskFormScreen)
- ✅ Interface atualizada para múltiplas fotos
- ✅ Integração com PhotoGalleryWidget
- ✅ Botões "Adicionar Fotos" e "Adicionar mais fotos"
- ✅ Remoção individual e em lote
- ✅ Salvamento das múltiplas fotos no banco de dados

### 6. Card de Tarefa (TaskCard)
- ✅ Badge atualizado mostrando contador de fotos
- ✅ Ícones diferentes para single/múltiplas fotos:
  - 📷 Una foto: `Icons.photo_camera`
  - 📚 Múltiplas: `Icons.photo_library` + contador
- ✅ Visualização em galeria para múltiplas fotos
- ✅ Modo tela cheia com navegação

## Fluxo de Uso

### Criando uma Nova Tarefa com Fotos
1. Na tela de criação/edição de tarefa
2. Toque em "Adicionar Fotos"
3. Escolha uma das opções:
   - **Câmera**: Tirar uma foto imediatamente
   - **Galeria - Uma foto**: Selecionar uma foto da galeria
   - **Galeria - Múltiplas fotos**: Selecionar várias fotos de uma vez
4. As fotos aparecem em uma grade
5. Toque em "Adicionar mais fotos" para adicionar mais
6. Toque no "x" para remover fotos individuais
7. Toque em "Remover todas" para limpar todas as fotos

### Visualizando Fotos na Lista de Tarefas
1. Tarefas com fotos mostram um badge azul
2. Badge mostra "Foto" (uma) ou "X Fotos" (múltiplas)
3. Toque no badge para abrir visualização:
   - **Uma foto**: Modal com a foto
   - **Múltiplas fotos**: Galeria em tela cheia com navegação

## Compatibilidade
- ✅ **Backward Compatible**: Tarefas antigas do Lab 3 continuam funcionando
- ✅ **Forward Compatible**: Novas tarefas usam múltiplas fotos automaticamente
- ✅ **Migração Automática**: Banco de dados migra automaticamente na primeira execução

## Estrutura de Arquivos

```
lib/
├── models/
│   └── task.dart                    # Modelo atualizado com múltiplas fotos
├── services/
│   ├── database_service.dart        # Schema v5 + migração
│   └── camera_service.dart          # Seleção múltipla + diálogos
├── widgets/
│   ├── photo_gallery_widget.dart    # Novo: Galeria de fotos
│   └── task_card.dart               # Badge atualizado
└── screens/
    └── task_form_screen.dart        # UI múltiplas fotos
```

## Dependências
- `image_picker: ^1.0.4`: Seleção de imagens/câmera
- `sqflite: ^2.3.0`: Banco de dados local
- Flutter SDK >= 3.0

## Testado em
- ✅ Emulador Android
- ✅ Criação de tarefas com múltiplas fotos
- ✅ Edição de tarefas existentes
- ✅ Migração de dados do Lab 3
- ✅ Visualização em galeria
- ✅ Remoção individual e em lote

## Próximas Melhorias Sugeridas
- [ ] Reordenação de fotos por drag & drop
- [ ] Compressão automática de imagens
- [ ] Upload para cloud storage
- [ ] Metadados das fotos (data, localização, etc.)
- [ ] Filtros e edição básica de imagens

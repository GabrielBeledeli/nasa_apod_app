# NASA APOD Feed App

Aplicativo mobile desenvolvido em **Flutter** para a disciplina acadêmica de Desenvolvimento Mobile. O projeto consome a API REST pública da **NASA (Astronomy Picture of the Day - APOD)**, demonstrando requisições HTTP assíncronas, desserialização JSON defensiva, gerenciamento completo de estados de interface (`loading`, `sucesso`, `erro com retry` e `paginação manual`), reprodução de mídia astronômica (imagens e vídeos) e renderização eficiente em lista rolável com **Dark Theme** espacial.

---

## 1. Identificação da API Utilizada

- **Nome Oficial**: NASA Astronomy Picture of the Day (APOD)
- **Provedor**: [NASA Science / NASA Open APIs](https://api.nasa.gov/)
- **Método e Endpoint Base**: `GET https://science.nasa.gov/wp-json/wp/v2/apod-basic/`
- **Autenticação**: Parâmetro de query `api_key`.
- **Parâmetros de Consulta Utilizados**:
  - `api_key`: Chave de acesso da API da NASA (`DEMO_KEY` por padrão ou chave própria configurada localmente no arquivo `.env`).
  - `date_from`: Data inicial do intervalo consultado no formato `YYMMDD`.
  - `date_to`: Data final do intervalo consultado no formato `YYMMDD`.
  - `per_page`: Quantidade máxima de registros retornados por página.
  - `_fields`: Seleção dos campos JSON utilizados pela aplicação.
- **Exemplo de Requisição**:
  ```http
  GET https://science.nasa.gov/wp-json/wp/v2/apod-basic/?api_key=DEMO_KEY&date_from=261027&date_to=261102
  ```
- **Formato da Resposta JSON**:
  Array de objetos contendo os metadados astronômicos diários (acervo disponível desde `16/06/1995`):
  ```json
  [
    {
      "date": "2026-09-11",
      "post_id": 1308668,
      "title": "M83: The Southern Pinwheel",
      "permalink": "https://science.nasa.gov/image-article/apod-2026-september-11-m83-the-southern-pinwheel/",
      "media_type": "image",
      "explanation": "Detailed Explanation...",
      "credit": "Aldo Zanetti",
      "copyright": "Aldo Zanetti",
      "url": "https://science.nasa.gov/image-article/apod-2026-september-11-m83-the-southern-pinwheel/",
      "hdurl": "https://assets.science.nasa.gov/dynamicimage/assets/science/cds/apod/apod/2026/september/M83_Final2_1x.jpg"
    }
  ]
  ```

### Configuração da Chave de API (`.env`)

Para o desenvolvimento deste projeto foi gerada uma chave própria da NASA, mantida exclusivamente em ambiente local no arquivo `.env` na raiz do projeto (bloqueado via `.gitignore` para não expor credenciais privadas no repositório público).

**Comportamento padrão**: Caso o arquivo `.env` não possua uma chave personalizada configurada, o sistema utilizará automaticamente a chave padrão `DEMO_KEY`.

#### Como gerar e configurar sua própria chave

1. Acesse [https://api.nasa.gov/](https://api.nasa.gov/) e vá até a seção **Generate API Key**.
2. Preencha seu nome e e-mail para receber gratuitamente sua chave pessoal.
3. Na raiz do projeto, copie o arquivo `.env.example` renomeando-o para `.env` e insira sua chave:
   ```env
   NASA_API_KEY=SUA_CHAVE_GERADA_AQUI
   ```
4. Execute o projeto normalmente — o `dotenv.load(fileName: '.env')` carregará a chave automaticamente na inicialização.

---

## 2. Arquitetura e Funcionalidades

O projeto segue uma arquitetura limpa e modularizada em camadas:

```text
nasa_apod_app/
├── .env.example                   # Modelo público para configuração da chave NASA_API_KEY
├── .env                           # Chave privada local na raiz (ignorado pelo Git)
└── lib/
    ├── main.dart                  # Inicialização do dotenv, MaterialApp e Dark Theme
    ├── models/
    │   └── apod_model.dart        # Modelo ApodModel com factory fromJson blindado contra nulos
    ├── services/
    │   └── apod_service.dart      # Camada HTTP (http.get), leitura da API Key, exceções e ordenação
    ├── screens/
    │   └── feed_screen.dart       # Tela principal, controle de estados, paginação de 7 dias e DatePicker
    └── widgets/
        ├── apod_card.dart         # Card visual com loadingBuilder, errorBuilder e descrição retrátil
        └── apod_video_player.dart # Player nativo para vídeos MP4 da NASA e abertura de vídeos externos
```

### Principais Destaques Técnicos
- **Ordem Cronológica Decrescente**: Registros sempre ordenados da data mais recente para a mais antiga.
- **Renderização Otimizada**: Uso de `ListView.builder` e redimensionamento de imagens (`cacheWidth: 800` e otimização no CDN) para consumo reduzido de memória.
- **Suporte Completo a Imagens e Vídeos**:
  - `Image.network` com `loadingBuilder` (indicador de progresso) e `errorBuilder`.
  - Player de vídeo nativo integrado ao card (`video_player`) para arquivos `.mp4` da NASA com miniatura de capa, além de abertura externa via `url_launcher` para vídeos embarcados (como YouTube).
- **Paginação Incremental Manual**: Botão `"Carregar fotos anteriores"` no rodapé que calcula e anexa os 7 dias antecedentes ao item mais antigo exibido.
- **Filtro Histórico via `DatePicker`**: Ícone de calendário na `AppBar` que permite saltar para qualquer data entre `16/06/1995` e a data atual.
- **Datas no Padrão Brasileiro**: Formatação `DD/MM/AAAA` utilizando o pacote `intl`.

---

## 3. Instruções de Execução

### Pré-requisitos
- **Flutter SDK** instalado e configurado no `PATH` (`flutter doctor` sem pendências críticas).
- Emulador Android / Simulador iOS, dispositivo físico conectado via USB ou suporte Desktop/Web habilitado.
- Conexão ativa com a internet para consumo da API da NASA.

### Passo a Passo

1. **Clone o repositório e acesse a pasta do projeto**:
   ```bash
   git clone <URL_DO_REPOSITORIO>
   cd nasa_apod_app
   ```

2. **Crie o arquivo `.env` na raiz a partir do modelo `.env.example`**:
   ```bash
   cp .env.example .env
   ```
   Edite o arquivo `.env` inserindo a chave gerada em [https://api.nasa.gov/](https://api.nasa.gov/) (ou mantenha o valor padrão para rodar com `DEMO_KEY`):
   ```env
   NASA_API_KEY=SUA_CHAVE_AQUI
   ```

3. **Instale as dependências do projeto**:
   ```bash
   flutter pub get
   ```

4. **Valide a análise estática do código (opcional)**:
   ```bash
   flutter analyze
   ```

5. **Execute o aplicativo no dispositivo ou emulador selecionado**:
   ```bash
   flutter run
   ```

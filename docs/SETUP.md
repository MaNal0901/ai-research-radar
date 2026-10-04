# Setup

## Prerequisites

- Windows 10/11 with **Docker Desktop** (WSL 2 backend)
- A Google account (Gemini API key + Gmail)
- A Telegram account
- A free OpenAlex API key

No credit card is needed for any of these.

## 1. Run n8n

```bash
docker run -d --name n8n -p 127.0.0.1:5678:5678 \
  -v n8n_data:/home/node/.n8n \
  -e "NODES_EXCLUDE=[]" \
  -e GENERIC_TIMEZONE=Africa/Casablanca -e TZ=Africa/Casablanca \
  n8nio/n8n
```

Open <http://localhost:5678> and create the owner account.

`NODES_EXCLUDE=[]` re-enables the `Execute Command` node, which the arXiv branch needs
(arXiv answers n8n's HTTP Request node with HTTP 406, so the feed is fetched with `wget`).
The port is bound to `127.0.0.1` so n8n is not exposed on your network.

## 2. Create the credentials

| Credential (n8n type) | Used by | How to get it |
|---|---|---|
| **Google Gemini (PaLM) API** | `Google Gemini Chat Model` | API key from Google AI Studio (free tier) |
| **Telegram API** | `Send a text message` | Create a bot with @BotFather, copy the token |
| **Gmail OAuth2** | `Send a message` | OAuth client in Google Cloud Console, following n8n's Gmail credential guide |
| **Query Auth** | `HTTP Request(OpenAlex)` | Free API key from OpenAlex; set it as a query parameter (check the parameter name in the node) |

## 3. Create the data table

In n8n, go to **Data tables** and create a table named `papers_seen` with these text/number columns:

`paper_id`, `title`, `source`, `category`, `score`

`examples/papers_seen.sample.csv` shows the expected format. The workflow uses this table to
remember every paper already scored, so it never reaches the digest twice.

## 4. Import the workflow

1. In n8n: **Workflows → Import from file** → `workflow/ai-research-radar.json`.
2. Re-select the credentials on each node that shows a warning.
3. In `Send a text message`, replace the placeholder `chatId` with yours
   (send a message to your bot, then open `https://api.telegram.org/bot<TOKEN>/getUpdates`).
4. In `Send a message` (Gmail), replace `you@example.com` with your address.
5. In the `Mémoriser` and `Nouveau papier ?` nodes, re-select the `papers_seen` table.

## 5. Test and activate

1. Click **Execute workflow** once manually and check the Telegram message and the email.
2. **Publish/activate** the workflow. The production URL
   `POST http://localhost:5678/webhook/run-radar` only responds when the workflow is active
   (the test URL `/webhook-test/...` works only while the editor is listening).
3. Trigger it from the command line:

```bash
curl -X POST http://localhost:5678/webhook/run-radar
```

To run it every week without touching anything, see [DEPLOYMENT.md](DEPLOYMENT.md).
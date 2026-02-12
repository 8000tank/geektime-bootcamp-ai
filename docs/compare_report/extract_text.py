from bs4 import BeautifulSoup
import sys

def extract_text(file_path):
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            html_content = f.read()
        soup = BeautifulSoup(html_content, 'html.parser')
        # Remove script and style elements
        for script in soup(["script", "style"]):
            script.decompose()
        text = soup.get_text()
        # Break into lines and remove leading/trailing space on each
        lines = (line.strip() for line in text.splitlines())
        # Break multi-headlines into a line each
        chunks = (phrase.strip() for line in lines for phrase in line.split("  "))
        # Drop blank lines
        text = '\n'.join(chunk for chunk in chunks if chunk)
        return text
    except Exception as e:
        return str(e)

print("--- STUDENT VERSION ---")
print(extract_text("docs/compare_report/Gemini DR_学生版.html")[:4000])
print("\n\n--- TEACHER VERSION ---")
print(extract_text("docs/compare_report/Gemini DR_导师版.html")[:4000])



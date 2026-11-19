from playwright.sync_api import sync_playwright
import sys
with sync_playwright() as p:
 b=p.chromium.launch(executable_path='/usr/bin/chromium',args=['--no-sandbox','--use-fake-device-for-media-stream','--use-fake-ui-for-media-stream','--autoplay-policy=no-user-gesture-required'])
 ctx=b.new_context(permissions=['microphone'])
 a,l=[ctx.new_page() for _ in range(2)]
 for page,role in [(a,'customer'),(l,'listener')]:
  page.goto(sys.argv[1]);page.locator('[data-role='+role+']').click()
 l.locator('#available').click();a.locator('#dial').click();l.locator('#accept').click()
 a.wait_for_function("document.querySelector('#remote').srcObject?.getAudioTracks().length === 1")
 a.wait_for_function("document.querySelector('#status').textContent.includes('60 coins')",timeout=55000)
 a.locator('#end').click();l.wait_for_function("document.querySelector('#wallet').textContent.includes('₹8.33')")
 print(a.locator('#receipt').inner_text(),l.locator('#wallet').inner_text())

import os, subprocess, json, textwrap
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT='/home/user/Blabla'
T=ROOT+'/release/tutorial_screens'
S=ROOT+'/release/screens_3.0'
# Usage: python3 tools/video/make_tutorial.py [out_dir]
# Needs: ffmpeg, RHVoice (apt install rhvoice rhvoice-russian) and the
# screenshots from test/tools/tutorial_screens_tool_test.dart and
# test/tools/screens_tool_test.dart in release/.
import sys
OUT=sys.argv[1] if len(sys.argv)>1 else ROOT+'/build/video'
os.makedirs(OUT,exist_ok=True)
F_REG=ROOT+'/assets/fonts/Roboto-Regular.ttf'
F_BOLD=ROOT+'/assets/fonts/Roboto-Bold.ttf'
GOLD=(212,178,106); WHITE=(255,255,255); MUTED=(170,186,210)
W,H=1920,1080

# (screen, title, caption, narration)
SCENES=[
 (None,'NexusTrade','Видеоинструкция: как начать работу',
  'Нексус Трейд — приложение для учёта международных торговых сделок, контрактов и документов. Покажем, как начать работу.'),
 (S+'/02_splash_4.6s.png','Запуск','Заставка с логотипом и слоганом. Нажмите на экран, чтобы пропустить её.',
  'При запуске показывается заставка с логотипом и слоганом. Нажмите на экран, чтобы пропустить её.'),
 (S+'/03_register.png','Регистрация','Почта или телефон и пароль.\nПароль защищает и вход, и резервные копии — запишите его.',
  'Создайте аккаунт по почте или номеру телефона и придумайте пароль. Пароль защищает и вход, и резервные копии. Запишите его и храните в надёжном месте.'),
 (T+'/03_dashboard.png','Главный экран','Месячная аналитика: контракты, оборот, чистая прибыль и маржа.',
  'Главный экран — месячная аналитика: число контрактов, оборот, чистая прибыль и маржа. Сделка относится к месяцу подписания.'),
 (T+'/04_dashboard_clients.png','Аналитика','Прибыль за 6 месяцев, прибыль по клиентам, статусы сделок.',
  'Ниже — прибыль за шесть месяцев, прибыль по клиентам и статусы сделок за месяц.'),
 (T+'/05_new_deal.png','Новая сделка','«Новая сделка» → выберите схему:\nBack-to-Back, трёхсторонний или двусторонний контракт.',
  'Чтобы создать сделку, нажмите «Новая сделка» и выберите схему: бэк ту бэк, трёхсторонний или двусторонний контракт.'),
 (T+'/06_contract1.png','Контракт №1','Номер, дата, покупатель и цена.\nЦена — вручную или от прибыли за единицу.',
  'Во вкладке «Контракт номер один» укажите номер, дату, покупателя и цену. Цену можно ввести вручную или задать прибыль за единицу — тогда цена рассчитается сама.'),
 (T+'/07_logistics.png','Контракт №2: логистика','Логистика суммой, за тонну или за фуру / контейнер.\nКоличество машин считается по весу.',
  'Во вкладке «Контракт номер два» — закупка у завода и логистика. Логистику можно считать суммой, за тонну или за фуру и контейнер. Количество машин подставляется по весу партии.'),
 (T+'/08_agent.png','Агентские','Процент от себестоимости товара или фиксированная сумма.\nНДС на услуги агента — отдельный переключатель.',
  'Агентские считаются процентом от себестоимости товара или фиксированной суммой. Налог на услуги агента включается отдельным переключателем.'),
 (T+'/09_summary.png','Итог','Номер сделки NT-ГГГГ-NNNN и расчёт чистой прибыли.',
  'Во вкладке «Итог» — номер сделки и расчёт чистой прибыли. Номер присваивается автоматически, его можно изменить. Нажмите «Сохранить».'),
 (T+'/10_deal.png','Карточка сделки','Прибыль, этапы, документы и доступ — в одном месте.',
  'Карточка сделки показывает прибыль, этапы, документы и доступ сотрудников.'),
 (T+'/11_stages.png','Этапы','Подписание → Предоплата → Загрузка → Оплата → Закрыт.\nИзменения сохраняются в истории.',
  'Этапы сделки: подписание, предоплата, загрузка, оплата и закрытие. Нажмите на этап или на кнопку «Следующий этап». Каждое изменение сохраняется в истории.'),
 (T+'/12_official.png','Официальный контракт','Прикрепите договор, укажите номер и дату.\nЗамена файла сохраняет прежнюю версию.',
  'В разделе «Официальный контракт» прикрепите подписанный договор и укажите его номер и дату. При замене файла прежняя версия сохраняется.'),
 (T+'/13_dossier.png','Досье документов','Инвойсы, приложения, доп. соглашения, корректировки.\nИсправленный документ — «Заменённый».',
  'В досье хранятся инвойсы, приложения, дополнительные соглашения и корректировки. Исправленный документ автоматически помечается как заменённый.'),
 (T+'/14_document.png','Документ','Просмотр, скачивание, замена, история версий.\nФайлы хранятся в зашифрованном виде.',
  'Документ можно открыть, скачать, заменить или удалить и посмотреть историю версий. Все файлы хранятся на телефоне в зашифрованном виде.'),
 (T+'/15_calculator.png','Калькулятор цены','Цена товара, количество, логистика, агентские и ваша прибыль.',
  'Вкладка «Цена» — калькулятор: цена товара, количество, логистика, агентские и ваша прибыль.'),
 (T+'/16_calculator_result.png','Результат расчёта','Цена для покупателя и прибыль по всей партии.',
  'Ниже — цена для покупателя и прибыль по всей партии. Из расчёта можно сразу создать сделку.'),
 (T+'/18_client.png','Клиенты','Контакты, сделки, суммы, прибыль по месяцам и документы клиента.',
  'В справочнике клиентов — контакты, сделки, суммы, прибыль по месяцам и все документы клиента.'),
 (T+'/19_users.png','Пользователи и роли','Администратор, менеджер, партнёр, клиент.\nВнутренние финансы видит только владелец.',
  'Добавьте пользователей: администратора, менеджера, партнёра или клиента. Внутренние финансы видит только владелец.'),
 (T+'/23_lock_profiles.png','Вход сотрудника','Выберите профиль и введите его PIN-код.',
  'На экране входа выберите профиль. Сотрудник входит по своему пин коду.'),
 (T+'/24_manager_deal.png','Вид менеджера','Этапы, поставка и документы — без прибыли и агентских.',
  'Менеджер видит этапы, условия поставки и документы, но не видит прибыль и агентские.'),
 (T+'/20_reminders_widget.png','Напоминания и виджет','Ежедневно, раз в 3 дня или раз в неделю.\nВиджет — на рабочем столе телефона.',
  'В настройках включите напоминания — каждый день, раз в три дня или раз в неделю — и настройте виджет для рабочего стола.'),
 (T+'/21_backup.png','Резервные копии','Раз в неделю — зашифрованная копия.\nОдно нажатие — сохранить в Google Drive.',
  'Раз в неделю приложение создаёт зашифрованную копию и предлагает сохранить её в Гугл Диск. Чтобы вернуть данные, нажмите «Восстановить из файла».'),
 (T+'/22_trash.png','Корзина','Удалённые сделки хранятся 15 дней — их можно восстановить.',
  'Удалённые сделки пятнадцать дней хранятся в корзине. Их можно восстановить.'),
 (None,'NexusTrade','Торгуйте уверенно',
  'Нексус Трейд. Торгуйте уверенно.'),
]

def font(path,size): return ImageFont.truetype(path,size)

def bg():
    im=Image.new('RGB',(W,H))
    d=ImageDraw.Draw(im)
    for y in range(H):
        t=y/H
        c=tuple(int(a*(1-t)+b*t) for a,b in zip((12,36,69),(5,11,22)))
        d.line([(0,y),(W,y)],fill=c)
    return im

logo=Image.open(ROOT+'/assets/brand/logo.png').convert('RGBA')

def phone(path):
    sc=Image.open(path).convert('RGB')
    h=940; w=int(sc.width*h/sc.height)
    sc=sc.resize((w,h),Image.LANCZOS)
    pad=16
    fr=Image.new('RGBA',(w+pad*2,h+pad*2),(0,0,0,0))
    m=Image.new('L',fr.size,0); ImageDraw.Draw(m).rounded_rectangle([0,0,fr.width-1,fr.height-1],48,fill=255)
    body=Image.new('RGBA',fr.size,(20,24,32,255)); fr.paste(body,(0,0),m)
    m2=Image.new('L',(w,h),0); ImageDraw.Draw(m2).rounded_rectangle([0,0,w-1,h-1],34,fill=255)
    fr.paste(sc,(pad,pad),m2)
    return fr

def wrap(text,f,maxw,d):
    lines=[]
    for para in text.split('\n'):
        cur=''
        for word in para.split(' '):
            t=(cur+' '+word).strip()
            if d.textlength(t,font=f)<=maxw: cur=t
            else: lines.append(cur); cur=word
        lines.append(cur)
    return lines

def card(i,n,shotpath,title,caption):
    im=bg(); d=ImageDraw.Draw(im)
    if shotpath is None:
        lg=logo.resize((300,300),Image.LANCZOS); im.paste(lg,((W-300)//2,230),lg)
        ft=font(F_BOLD,96); tw=d.textlength(title,font=ft)
        d.text(((W-tw)/2,560),title,font=ft,fill=GOLD)
        fc=font(F_REG,44); cw=d.textlength(caption,font=fc)
        d.text(((W-cw)/2,690),caption,font=fc,fill=WHITE)
    else:
        ph=phone(shotpath)
        # glow
        glow=Image.new('RGBA',(ph.width+80,ph.height+80),(0,0,0,0))
        ImageDraw.Draw(glow).rounded_rectangle([40,40,ph.width+40,ph.height+40],56,fill=(80,140,255,90))
        glow=glow.filter(ImageFilter.GaussianBlur(28))
        px=230; py=(H-ph.height)//2
        im.paste(glow,(px-40,py-40),glow); im.paste(ph,(px,py),ph)
        x=px+ph.width+140; maxw=W-x-120
        lg=logo.resize((72,72),Image.LANCZOS); im.paste(lg,(x,150),lg)
        d.text((x+92,166),'NexusTrade',font=font(F_BOLD,36),fill=GOLD)
        d.text((x,300),f'Шаг {i} из {n}',font=font(F_REG,32),fill=MUTED)
        ft=font(F_BOLD,64)
        y=350
        for line in wrap(title,ft,maxw,d):
            d.text((x,y),line,font=ft,fill=WHITE); y+=80
        y+=30
        d.rectangle([x,y,x+90,y+6],fill=GOLD); y+=40
        fc=font(F_REG,40)
        for line in wrap(caption,fc,maxw,d):
            d.text((x,y),line,font=fc,fill=(225,232,245)); y+=56
    # progress bar
    d.rectangle([0,H-10,W,H],fill=(25,40,70))
    d.rectangle([0,H-10,int(W*(i)/(n+1)),H],fill=GOLD)
    return im

n=len(SCENES)-2
parts=[]; srt=[]; t0=0.0
def ts(t):
    h=int(t//3600); m=int(t%3600//60); s=t%60
    return f'{h:02d}:{m:02d}:{int(s):02d},{int((s-int(s))*1000):03d}'
for idx,(shotp,title,cap,narr) in enumerate(SCENES):
    step=idx if 0<idx<len(SCENES)-1 else 0
    img=card(step,n,shotp,title,cap) if shotp else card(len(SCENES)-1 if idx else 0,n,None,title,cap)
    png=f'{OUT}/s{idx:02d}.png'; img.save(png)
    wav=f'{OUT}/s{idx:02d}.wav'
    subprocess.run(['RHVoice-test','-p','aleksandr-hq','-o',wav],input=narr.encode(),check=True)
    dur=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','csv=p=0',wav]))
    total=dur+1.4
    mp4=f'{OUT}/s{idx:02d}.mp4'
    subprocess.run(['ffmpeg','-y','-loglevel','error','-loop','1','-i',png,'-i',wav,
        '-filter_complex',f"[0:v]scale=1920:1080,zoompan=z='min(zoom+0.00025,1.03)':d={int(total*30)}:s=1920x1080:fps=30,fade=t=in:st=0:d=0.4,fade=t=out:st={total-0.4:.2f}:d=0.4[v];[1:a]adelay=500|500,apad,atrim=0:{total:.2f},afade=t=out:st={total-0.3:.2f}:d=0.3[a]",
        '-map','[v]','-map','[a]','-t',f'{total:.2f}','-c:v','libx264','-preset','medium','-crf','20','-pix_fmt','yuv420p',
        '-c:a','aac','-b:a','160k','-ar','48000','-ac','2',mp4],check=True)
    parts.append(mp4)
    srt.append(f'{idx+1}\n{ts(t0+0.5)} --> {ts(t0+0.5+dur)}\n{narr}\n')
    t0+=total
    print(idx,title,round(total,1),flush=True)
with open(f'{OUT}/list.txt','w') as f:
    for p in parts: f.write(f"file '{p}'\n")
subprocess.run(['ffmpeg','-y','-loglevel','error','-f','concat','-safe','0','-i',f'{OUT}/list.txt','-c','copy','-movflags','+faststart',f'{OUT}/NexusTrade_tutorial_ru.mp4'],check=True)
open(f'{OUT}/NexusTrade_tutorial_ru.srt','w').write('\n'.join(srt))
print('TOTAL',round(t0,1))

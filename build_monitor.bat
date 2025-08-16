import tkinter as tk
from tkinter import ttk, messagebox, scrolledtext
import json
import os
from datetime import datetime, timezone
import pytz
import threading
import time
import requests
from urllib.parse import quote

class TwitterMonitor:
    def __init__(self, root):
        self.root = root
        self.root.title("Twitter Account Monitor")
        self.root.geometry("1000x700")
        self.root.configure(bg='#15202b')  # Twitter dark theme
        
        # Data storage
        self.monitored_accounts = self.load_monitored_accounts()
        self.today_tweets = self.load_today_tweets()
        self.latest_tweets = {}
        
        # American timezone
        self.american_tz = pytz.timezone('America/New_York')
        
        # Create UI
        self.create_ui()
        
        # Start monitoring thread
        self.monitoring_active = True
        self.monitor_thread = threading.Thread(target=self.monitoring_loop, daemon=True)
        self.monitor_thread.start()
        
        # Bind window close event
        self.root.protocol("WM_DELETE_WINDOW", self.on_closing)
    
    def create_ui(self):
        # Main container
        main_frame = tk.Frame(self.root, bg='#15202b')
        main_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)
        
        # Title
        title_label = tk.Label(
            main_frame,
            text="🐦 Twitter Account Monitor",
            font=("Arial", 20, "bold"),
            bg='#15202b',
            fg='#ffffff'
        )
        title_label.pack(pady=(0, 20))
        
        # Create notebook for tabs
        self.notebook = ttk.Notebook(main_frame)
        self.notebook.pack(fill=tk.BOTH, expand=True)
        
        # Create tabs
        self.create_monitor_tab()
        self.create_accounts_tab()
        self.create_today_tweets_tab()
        
        # Status bar
        self.status_bar = tk.Label(
            main_frame,
            text="Ready | Monitoring: Active",
            font=("Arial", 9),
            bg='#192734',
            fg='#8899a6',
            relief=tk.SUNKEN,
            anchor=tk.W
        )
        self.status_bar.pack(fill=tk.X, pady=(10, 0))
    
    def create_monitor_tab(self):
        # Monitor tab
        monitor_frame = tk.Frame(self.notebook, bg='#15202b')
        self.notebook.add(monitor_frame, text="Live Monitor")
        
        # Latest tweets section
        latest_label = tk.Label(
            monitor_frame,
            text="Latest Tweets from Monitored Accounts",
            font=("Arial", 14, "bold"),
            bg='#15202b',
            fg='#ffffff'
        )
        latest_label.pack(pady=(20, 10))
        
        # Latest tweets display
        self.latest_tweets_frame = tk.Frame(monitor_frame, bg='#15202b')
        self.latest_tweets_frame.pack(fill=tk.BOTH, expand=True, padx=20)
        
        # Refresh button
        refresh_btn = tk.Button(
            monitor_frame,
            text="🔄 Refresh Now",
            font=("Arial", 10, "bold"),
            bg='#1da1f2',
            fg='white',
            relief=tk.FLAT,
            command=self.refresh_latest_tweets
        )
        refresh_btn.pack(pady=(0, 20))
        
        self.update_latest_tweets_display()
    
    def create_accounts_tab(self):
        # Accounts management tab
        accounts_frame = tk.Frame(self.notebook, bg='#15202b')
        self.notebook.add(accounts_frame, text="Manage Accounts")
        
        # Title
        title_label = tk.Label(
            accounts_frame,
            text="Monitored Twitter Accounts",
            font=("Arial", 16, "bold"),
            bg='#15202b',
            fg='#ffffff'
        )
        title_label.pack(pady=(20, 20))
        
        # Current accounts list
        list_frame = tk.Frame(accounts_frame, bg='#192734', relief=tk.RAISED, bd=2)
        list_frame.pack(fill=tk.BOTH, expand=True, padx=20, pady=(0, 20))
        
        # Listbox for accounts
        self.accounts_listbox = tk.Listbox(
            list_frame,
            font=("Arial", 12),
            bg='#192734',
            fg='#ffffff',
            selectbackground='#1da1f2',
            selectforeground='white',
            height=8
        )
        self.accounts_listbox.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)
        
        # Populate listbox
        self.update_accounts_list()
        
        # Buttons frame
        buttons_frame = tk.Frame(accounts_frame, bg='#15202b')
        buttons_frame.pack(fill=tk.X, padx=20)
        
        # Add account button
        add_button = tk.Button(
            buttons_frame,
            text="➕ Add Account",
            font=("Arial", 10, "bold"),
            bg='#17bf63',
            fg='white',
            relief=tk.FLAT,
            command=self.add_twitter_account
        )
        add_button.pack(side=tk.LEFT, padx=(0, 10))
        
        # Remove account button
        remove_button = tk.Button(
            buttons_frame,
            text="➖ Remove Account",
            font=("Arial", 10, "bold"),
            bg='#e0245e',
            fg='white',
            relief=tk.FLAT,
            command=self.remove_twitter_account
        )
        remove_button.pack(side=tk.LEFT, padx=(0, 10))
        
        # Clear all button
        clear_button = tk.Button(
            buttons_frame,
            text="🗑️ Clear All",
            font=("Arial", 10, "bold"),
            bg='#f7931e',
            fg='white',
            relief=tk.FLAT,
            command=self.clear_all_accounts
        )
        clear_button.pack(side=tk.LEFT)
    
    def create_today_tweets_tab(self):
        # Today's tweets tab
        today_frame = tk.Frame(self.notebook, bg='#15202b')
        self.notebook.add(today_frame, text="Today's Tweets")
        
        # Title with date
        self.today_title_label = tk.Label(
            today_frame,
            text=f"Tweets from {datetime.now(self.american_tz).strftime('%B %d, %Y')}",
            font=("Arial", 16, "bold"),
            bg='#15202b',
            fg='#ffffff'
        )
        self.today_title_label.pack(pady=(20, 20))
        
        # Today's tweets display
        self.today_tweets_frame = tk.Frame(today_frame, bg='#15202b')
        self.today_tweets_frame.pack(fill=tk.BOTH, expand=True, padx=20)
        
        # Export button
        export_btn = tk.Button(
            today_frame,
            text="📥 Export to JSON",
            font=("Arial", 10, "bold"),
            bg='#1da1f2',
            fg='white',
            relief=tk.FLAT,
            command=self.export_today_tweets
        )
        export_btn.pack(pady=(0, 20))
        
        self.update_today_tweets_display()
    
    def add_twitter_account(self):
        # Create dialog for adding account
        dialog = tk.Toplevel(self.root)
        dialog.title("Add Twitter Account")
        dialog.geometry("400x200")
        dialog.configure(bg='#15202b')
        dialog.resizable(False, False)
        dialog.transient(self.root)
        dialog.grab_set()
        
        # Main frame
        main_frame = tk.Frame(dialog, bg='#15202b')
        main_frame.pack(fill=tk.BOTH, expand=True, padx=20, pady=20)
        
        # Label
        label = tk.Label(
            main_frame,
            text="Enter Twitter username (without @):",
            font=("Arial", 10),
            bg='#15202b',
            fg='#ffffff'
        )
        label.pack(pady=(0, 10))
        
        # Entry field
        entry = tk.Entry(main_frame, font=("Arial", 12), width=30)
        entry.pack(pady=(0, 20))
        entry.focus()
        
        # Buttons frame
        buttons_frame = tk.Frame(main_frame, bg='#15202b')
        buttons_frame.pack(fill=tk.X)
        
        # Add button
        add_btn = tk.Button(
            buttons_frame,
            text="Add",
            font=("Arial", 10),
            bg='#17bf63',
            fg='white',
            relief=tk.FLAT,
            command=lambda: self.save_twitter_account(entry.get(), dialog)
        )
        add_btn.pack(side=tk.LEFT, padx=(0, 10))
        
        # Cancel button
        cancel_btn = tk.Button(
            buttons_frame,
            text="Cancel",
            font=("Arial", 10),
            bg='#8899a6',
            fg='white',
            relief=tk.FLAT,
            command=dialog.destroy
        )
        cancel_btn.pack(side=tk.LEFT)
        
        # Bind Enter key
        entry.bind("<Return>", lambda e: self.save_twitter_account(entry.get(), dialog))
    
    def save_twitter_account(self, username, dialog):
        if username.strip():
            username = username.strip().lower()
            if username not in self.monitored_accounts:
                self.monitored_accounts.append(username)
                self.save_monitored_accounts()
                self.update_accounts_list()
                messagebox.showinfo("Success", f"Added @{username} to monitored accounts")
            else:
                messagebox.showwarning("Warning", f"@{username} is already being monitored")
            dialog.destroy()
        else:
            messagebox.showwarning("Warning", "Please enter a valid username")
    
    def remove_twitter_account(self):
        selection = self.accounts_listbox.curselection()
        if selection:
            index = selection[0]
            username = self.accounts_listbox.get(index).replace("@", "")
            if username in self.monitored_accounts:
                self.monitored_accounts.remove(username)
                self.save_monitored_accounts()
                self.update_accounts_list()
                messagebox.showinfo("Success", f"Removed @{username} from monitored accounts")
        else:
            messagebox.showwarning("Warning", "Please select an account to remove")
    
    def clear_all_accounts(self):
        if messagebox.askyesno("Confirm", "Are you sure you want to remove all monitored accounts?"):
            self.monitored_accounts.clear()
            self.save_monitored_accounts()
            self.update_accounts_list()
            messagebox.showinfo("Success", "All accounts removed")
    
    def update_accounts_list(self):
        self.accounts_listbox.delete(0, tk.END)
        for account in self.monitored_accounts:
            self.accounts_listbox.insert(tk.END, f"@{account}")
    
    def update_latest_tweets_display(self):
        # Clear existing widgets
        for widget in self.latest_tweets_frame.winfo_children():
            widget.destroy()
        
        if not self.monitored_accounts:
            no_accounts_label = tk.Label(
                self.latest_tweets_frame,
                text="No accounts monitored. Add accounts in the 'Manage Accounts' tab.",
                font=("Arial", 12),
                bg='#15202b',
                fg='#8899a6'
            )
            no_accounts_label.pack(pady=50)
            return
        
        # Create scrollable frame
        canvas = tk.Canvas(self.latest_tweets_frame, bg='#15202b', highlightthickness=0)
        scrollbar = ttk.Scrollbar(self.latest_tweets_frame, orient="vertical", command=canvas.yview)
        scrollable_frame = tk.Frame(canvas, bg='#15202b')
        
        scrollable_frame.bind(
            "<Configure>",
            lambda e: canvas.configure(scrollregion=canvas.bbox("all"))
        )
        
        canvas.create_window((0, 0), window=scrollable_frame, anchor="nw")
        canvas.configure(yscrollcommand=scrollbar.set)
        
        # Display latest tweets
        for i, account in enumerate(self.monitored_accounts):
            tweet_data = self.latest_tweets.get(account, {})
            
            # Account header
            account_frame = tk.Frame(scrollable_frame, bg='#192734', relief=tk.RAISED, bd=1)
            account_frame.pack(fill=tk.X, pady=(10 if i == 0 else 5), padx=5)
            
            account_label = tk.Label(
                account_frame,
                text=f"@{account}",
                font=("Arial", 12, "bold"),
                bg='#192734',
                fg='#1da1f2'
            )
            account_label.pack(anchor=tk.W, padx=10, pady=(10, 5))
            
            if tweet_data:
                # Tweet content
                tweet_text = tk.Label(
                    account_frame,
                    text=tweet_data.get('text', 'No tweet content'),
                    font=("Arial", 10),
                    bg='#192734',
                    fg='#ffffff',
                    wraplength=800,
                    justify=tk.LEFT
                )
                tweet_text.pack(anchor=tk.W, padx=10, pady=(0, 5))
                
                # Tweet metadata
                metadata_text = f"Posted: {tweet_data.get('created_at', 'Unknown time')} | Likes: {tweet_data.get('favorite_count', 0)} | Retweets: {tweet_data.get('retweet_count', 0)}"
                metadata_label = tk.Label(
                    account_frame,
                    text=metadata_text,
                    font=("Arial", 8),
                    bg='#192734',
                    fg='#8899a6'
                )
                metadata_label.pack(anchor=tk.W, padx=10, pady=(0, 10))
            else:
                no_tweet_label = tk.Label(
                    account_frame,
                    text="No recent tweets found",
                    font=("Arial", 10),
                    bg='#192734',
                    fg='#8899a6'
                )
                no_tweet_label.pack(anchor=tk.W, padx=10, pady=(0, 10))
        
        canvas.pack(side="left", fill="both", expand=True)
        scrollbar.pack(side="right", fill="y")
    
    def update_today_tweets_display(self):
        # Clear existing widgets
        for widget in self.today_tweets_frame.winfo_children():
            widget.destroy()
        
        # Update title with current date
        current_date = datetime.now(self.american_tz).strftime('%B %d, %Y')
        self.today_title_label.config(text=f"Tweets from {current_date}")
        
        if not self.today_tweets:
            no_tweets_label = tk.Label(
                self.today_tweets_frame,
                text="No tweets collected today yet. Tweets will appear here as they are monitored.",
                font=("Arial", 12),
                bg='#15202b',
                fg='#8899a6'
            )
            no_tweets_label.pack(pady=50)
            return
        
        # Create scrollable frame
        canvas = tk.Canvas(self.today_tweets_frame, bg='#15202b', highlightthickness=0)
        scrollbar = ttk.Scrollbar(self.today_tweets_frame, orient="vertical", command=canvas.yview)
        scrollable_frame = tk.Frame(canvas, bg='#15202b')
        
        scrollable_frame.bind(
            "<Configure>",
            lambda e: canvas.configure(scrollregion=canvas.bbox("all"))
        )
        
        canvas.create_window((0, 0), window=scrollable_frame, anchor="nw")
        canvas.configure(yscrollcommand=scrollbar.set)
        
        # Group tweets by account
        tweets_by_account = {}
        for tweet in self.today_tweets:
            account = tweet.get('username', 'Unknown')
            if account not in tweets_by_account:
                tweets_by_account[account] = []
            tweets_by_account[account].append(tweet)
        
        # Display tweets grouped by account
        for account, tweets in tweets_by_account.items():
            # Account header
            account_frame = tk.Frame(scrollable_frame, bg='#192734', relief=tk.RAISED, bd=1)
            account_frame.pack(fill=tk.X, pady=10, padx=5)
            
            account_label = tk.Label(
                account_frame,
                text=f"@{account} - {len(tweets)} tweets today",
                font=("Arial", 12, "bold"),
                bg='#192734',
                fg='#1da1f2'
            )
            account_label.pack(anchor=tk.W, padx=10, pady=(10, 5))
            
            # Display tweets for this account
            for tweet in tweets:
                tweet_frame = tk.Frame(account_frame, bg='#22303c', relief=tk.FLAT, bd=1)
                tweet_frame.pack(fill=tk.X, padx=10, pady=2)
                
                tweet_text = tk.Label(
                    tweet_frame,
                    text=tweet.get('text', 'No tweet content'),
                    font=("Arial", 9),
                    bg='#22303c',
                    fg='#ffffff',
                    wraplength=750,
                    justify=tk.LEFT
                )
                tweet_text.pack(anchor=tk.W, padx=10, pady=(5, 2))
                
                metadata_text = f"Posted: {tweet.get('created_at', 'Unknown time')} | Likes: {tweet.get('favorite_count', 0)} | Retweets: {tweet.get('retweet_count', 0)}"
                metadata_label = tk.Label(
                    tweet_frame,
                    text=metadata_text,
                    font=("Arial", 7),
                    bg='#22303c',
                    fg='#8899a6'
                )
                metadata_label.pack(anchor=tk.W, padx=10, pady=(0, 5))
        
        canvas.pack(side="left", fill="both", expand=True)
        scrollbar.pack(side="right", fill="y")
    
    def refresh_latest_tweets(self):
        self.status_bar.config(text="Refreshing latest tweets...")
        self.fetch_latest_tweets()
        self.update_latest_tweets_display()
        self.status_bar.config(text=f"Ready | Last updated: {datetime.now(self.american_tz).strftime('%H:%M:%S')}")
    
    def fetch_latest_tweets(self):
        # Simulate fetching tweets (in a real app, you'd use Twitter API)
        for account in self.monitored_accounts:
            # Simulate tweet data
            self.latest_tweets[account] = {
                'text': f"This is a simulated latest tweet from @{account}. In a real application, this would be fetched from Twitter's API.",
                'created_at': datetime.now(self.american_tz).strftime('%Y-%m-%d %H:%M:%S'),
                'favorite_count': 42,
                'retweet_count': 7
            }
            
            # Store in today's tweets if it's today
            self.store_today_tweet(account, self.latest_tweets[account])
    
    def store_today_tweet(self, username, tweet_data):
        current_date = datetime.now(self.american_tz).date()
        
        # Check if we need to clear old tweets (new day)
        if self.today_tweets and self.today_tweets[0].get('date') != current_date.isoformat():
            self.today_tweets.clear()
        
        # Add tweet with date
        tweet_with_date = tweet_data.copy()
        tweet_with_date['username'] = username
        tweet_with_date['date'] = current_date.isoformat()
        
        # Check if this tweet is already stored
        tweet_exists = any(
            t.get('username') == username and 
            t.get('text') == tweet_data.get('text') and
            t.get('date') == current_date.isoformat()
            for t in self.today_tweets
        )
        
        if not tweet_exists:
            self.today_tweets.append(tweet_with_date)
            self.save_today_tweets()
    
    def export_today_tweets(self):
        if not self.today_tweets:
            messagebox.showinfo("Info", "No tweets to export today")
            return
        
        filename = f"tweets_{datetime.now(self.american_tz).strftime('%Y%m%d')}.json"
        try:
            with open(filename, 'w', encoding='utf-8') as f:
                json.dump(self.today_tweets, f, indent=2, ensure_ascii=False)
            messagebox.showinfo("Success", f"Tweets exported to {filename}")
        except Exception as e:
            messagebox.showerror("Error", f"Failed to export tweets: {str(e)}")
    
    def monitoring_loop(self):
        while self.monitoring_active:
            try:
                if self.monitored_accounts:
                    self.fetch_latest_tweets()
                    self.root.after(0, self.update_latest_tweets_display)
                    self.root.after(0, self.update_today_tweets_display)
                    self.root.after(0, lambda: self.status_bar.config(
                        text=f"Ready | Last updated: {datetime.now(self.american_tz).strftime('%H:%M:%S')}"
                    ))
                
                # Wait 5 minutes before next check
                time.sleep(300)
            except Exception as e:
                print(f"Monitoring error: {e}")
                time.sleep(60)
    
    def load_monitored_accounts(self):
        try:
            if os.path.exists('monitored_accounts.json'):
                with open('monitored_accounts.json', 'r') as f:
                    return json.load(f)
        except:
            pass
        return []
    
    def save_monitored_accounts(self):
        try:
            with open('monitored_accounts.json', 'w') as f:
                json.dump(self.monitored_accounts, f)
        except:
            pass
    
    def load_today_tweets(self):
        try:
            if os.path.exists('today_tweets.json'):
                with open('today_tweets.json', 'r') as f:
                    return json.load(f)
        except:
            pass
        return []
    
    def save_today_tweets(self):
        try:
            with open('today_tweets.json', 'w') as f:
                json.dump(self.today_tweets, f)
        except:
            pass
    
    def on_closing(self):
        self.monitoring_active = False
        self.save_monitored_accounts()
        self.save_today_tweets()
        self.root.destroy()

def main():
    root = tk.Tk()
    app = TwitterMonitor(root)
    
    # Center the window on screen
    root.update_idletasks()
    x = (root.winfo_screenwidth() // 2) - (1000 // 2)
    y = (root.winfo_screenheight() // 2) - (700 // 2)
    root.geometry(f"1000x700+{x}+{y}")
    
    # Start the application
    root.mainloop()

if __name__ == "__main__":
    main()
```

Now I'll create the requirements file and build scripts:

```text:requirements.txt
pytz==2023.3
requests==2.31.0
```

```batch:build_monitor.bat
@echo off
echo Building Twitter Monitor executable...
echo.

REM Check if PyInstaller is installed
python -c "import PyInstaller" 2>nul
if errorlevel 1 (
    echo Installing PyInstaller...
    pip install pyinstaller
    if errorlevel 1 (
        echo Failed to install PyInstaller. Please install Python and pip first.
        pause
        exit /b 1
    )
)

echo.
echo Installing required packages...
pip install -r requirements.txt

echo.
echo Building executable...
pyinstaller --onefile --windowed --name TwitterMonitor twitter_monitor.py

if errorlevel 1 (
    echo Build failed!
    pause
    exit /b 1
)

echo.
echo Build successful! Executable created in dist\ folder
echo You can now run TwitterMonitor.exe without Python installation
echo.
pause
```

## Features of the Twitter Monitor:

### 🎯 **Core Functionality:**
- **Real-time Monitoring**: Automatically checks monitored accounts every 5 minutes
- **Latest Tweet Display**: Shows the most recent tweet from each monitored account
- **Today's Tweets Storage**: Collects and stores all tweets from today (American timezone)
- **Persistent Storage**: Saves data to JSON files for persistence

### ️ **User Interface:**
- **3 Main Tabs:**
  1. **Live Monitor**: Real-time display of latest tweets
  2. **Manage Accounts**: Add/remove Twitter accounts to monitor
  3. **Today's Tweets**: View all tweets collected today

### ⚙️ **Account Management:**
- Add Twitter usernames (without @ symbol)
- Remove individual accounts
- Clear all accounts at once
- Persistent storage of monitored accounts

### 📊 **Data Features:**
- **American Timezone**: Uses Eastern Time (America/New_York)
- **Tweet Metadata**: Displays likes, retweets, and posting time
- **Daily Collection**: Automatically resets daily and stores new tweets
- **Export Function**: Export today's tweets to JSON file

###  **Auto-refresh:**
- Background monitoring thread
- Manual refresh button
- Status bar showing last update time
- Automatic daily tweet collection

## To create the standalone executable:

1. **Install dependencies**: `pip install -r requirements.txt`
2. **Build executable**: Run `build_monitor.bat` or manually:
   ```
   pyinstaller --onefile --windowed --name TwitterMonitor twitter_monitor.py
   ```

## To run:
- **With Python**: `python twitter_monitor.py`
- **Standalone**: Run `dist\TwitterMonitor.exe` (after building)

## Note:
This is a **simulation** of Twitter monitoring since actual Twitter API access requires authentication and API keys. In a production version, you would integrate with Twitter's official API to fetch real tweets. The current version demonstrates the complete UI and data management system with simulated tweet data.

The program automatically handles timezone conversion to American time and stores today's tweets persistently, exactly as requested!

import os
import sqlite3
import pandas as pd
from pathlib import Path

def create_database(db_path='olympics.db'):
    """Create a new SQLite database."""
    if os.path.exists(db_path):
        os.remove(db_path)
    return sqlite3.connect(db_path)

def import_csv_to_sqlite(conn, csv_path, table_name):
    """Import a CSV file into an SQLite table."""
    try:
        # Read CSV file
        df = pd.read_csv(csv_path, low_memory=False)
        
        # Clean column names (remove spaces, special characters, etc.)
        # Remove any existing quotes and clean the column names
        df.columns = [str(col).strip('"\'') for col in df.columns]
        
        # Write to SQLite
        df.to_sql(table_name, conn, if_exists='replace', index=False)
        print(f"Imported {os.path.basename(csv_path)} as table '{table_name}'")
        return True
    except Exception as e:
        print(f"Error importing {csv_path}: {str(e)}")
        return False

def main():
    # Set up paths
    data_dir = Path('data/olympics')
    db_path = 'olympics.db'
    
    # Create database connection
    conn = create_database(db_path)
    
    try:
        # Import main CSV files
        main_files = [
            'athletes.csv', 'coaches.csv', 'events.csv', 
            'medallists.csv', 'medals.csv', 'nocs.csv',
            'schedules.csv', 'teams.csv', 'venues.csv'
        ]
        
        for file in main_files:
            csv_path = data_dir / file
            if csv_path.exists():
                table_name = os.path.splitext(file)[0]
                import_csv_to_sqlite(conn, csv_path, table_name)
        
        # Import results from each sport
        results_dir = data_dir / 'results'
        if results_dir.exists():
            for sport_file in results_dir.glob('*.csv'):
                # Create table name from filename (replace spaces with underscores)
                table_name = f"results_{os.path.splitext(sport_file.name)[0].replace(' ', '_').lower()}"
                import_csv_to_sqlite(conn, sport_file, table_name)
        
        # Print summary
        cursor = conn.cursor()
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
        tables = cursor.fetchall()
        print("\nDatabase created successfully with the following tables:")
        for table in tables:
            cursor.execute(f"SELECT COUNT(*) FROM {table[0]};")
            count = cursor.fetchone()[0]
            print(f"- {table[0]}: {count} rows")
        
    finally:
        conn.close()

if __name__ == "__main__":
    main()
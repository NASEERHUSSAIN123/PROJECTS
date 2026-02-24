from pymongo import MongoClient

# Connect to your local MongoDB
client = MongoClient('mongodb://localhost:27017/')
db = client['APSCHE']
users_collection = db['userdata']

# Delete all documents in the userdata collection
deleted_data = users_collection.delete_many({})

print(f"Success! Deleted {deleted_data.deleted_count} user(s) from the database.")
print("Your project is now completely fresh.")
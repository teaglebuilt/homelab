// MongoDB initialization script for Unifi test database
db = db.getSiblingDB('unifi');

// Create unifi user with appropriate permissions
db.createUser({
  user: 'unifi',
  pwd: 'unifi_test_password_change_me',
  roles: [
    {
      role: 'dbOwner',
      db: 'unifi'
    }
  ]
});

// Create unifi_stat database for statistics
db = db.getSiblingDB('unifi_stat');
db.createUser({
  user: 'unifi',
  pwd: 'unifi_test_password_change_me',
  roles: [
    {
      role: 'dbOwner',
      db: 'unifi_stat'
    }
  ]
});

print('MongoDB initialized for Unifi test environment');

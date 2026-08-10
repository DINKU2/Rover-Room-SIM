function homeDir = rover_user_home()
%ROVER_USER_HOME Resolve home directory (HOME can be empty in some MATLAB launches).
    homeDir = getenv('HOME');
    if strlength(homeDir) == 0
        homeDir = getenv('USERPROFILE');
    end
    if strlength(homeDir) == 0
        homeDir = char(java.lang.System.getProperty('user.home'));
    end
end

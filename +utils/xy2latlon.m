function [lat, lon] = xy2latlon(x, y, lat0, lon0)
a  = 6378.1370; % equatorial radius [km]
b = 6356.7523; % polar radius [km]
r_numerator = (a^2*cosd(lat0))^2 + (b^2*sind(lat0))^2;
r_denominator = (a*cosd(lat0))^2 + (b*sind(lat0))^2;
r = sqrt(r_numerator/r_denominator).*1000; % radius [km]
 
lat = (y./r)*180/pi + lat0;
lon = x./(r.*cosd(lat0))*180/pi + lon0;

% eventually it'd be good to add wgs84

end
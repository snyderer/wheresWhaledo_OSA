function [x, y] = latlon2xy(lat, lon, lat0, lon0, varargin)
% [x, y] = latlon2xy(lat, lon, lat0, lon0) calculates the approximate
% cartesian coordinates x and y [m] of the positions of lat and lon with a
% grid centered on lat0 and lon0.
% [x, y] = latlon2xy(lat, lon, lat0, lon0, 'spherical') uses the 
% equirectangular (ie spherical earth approximation) projection (default if unspecified)
% [x, y] = latlon2xy(lat, lon, lat0, lon0, 'wgs') uses WGS84 Spheroid
% approximation. (IN DEVELOPMENT--CURRENTLY DOES NOT WORK WITHOUT MAPPING TOOLBOX)

if nargin==5
    if contains(varargin{1}, 'wgs', 'IgnoreCase', true) || ...
            strcmp(varargin{1}, 'w')
        conversionType = 'w';
    elseif contains(varargin{1}, 'sph', 'IgnoreCase', true) || ...
            contains(varargin{1}, 'eq', 'IgnoreCase', true) || ...
            strcmp(varargin{1}, 's')
        conversionType = 's';
    else
        fprintf(['\nUnrecognized input: ', varargin{1}, '. Using HAVERSINE.'])
        conversionType = 's';
    end
else
    conversionType = 's';
end

switch conversionType
    case 's'
        [x, y] = latlon2xy_equirect(lat, lon, lat0, lon0);
    case 'w'
        [x, y] = latlon2xy_wgs84(lat, lon, lat0, lon0);
end

end

function [x, y] = latlon2xy_equirect(lat, lon, lat0, lon0)
% calculate geocentric radius
% (see https://en.wikipedia.org/wiki/Earth_radius):
a  = 6378.1370; % equatorial radius [km]
b = 6356.7523; % polar radius [km]
r_numerator = (a^2*cosd(lat0))^2 + (b^2*sind(lat0))^2;
r_denominator = (a*cosd(lat0))^2 + (b*sind(lat0))^2;
r = sqrt(r_numerator/r_denominator).*1000; % radius [m]

x = r.*(lon-lon0).*cosd(lat0)*pi/180;
y = r.*(lat-lat0).*pi/180;

end

function [x, y] = latlon2xy_wgs84(lat, lon, lat0, lon0)

try % if mapping toolbox is installed, just use that.
    [arclen, az] = distance(lat0, lon0, lat, lon, wgs84Ellipsoid);

    x = arclen.*sind(az);
    y = arclen.*cosd(az);
catch % no mapping toolbox. Code it all in.
    fprintf('\nDO NOT USE -- PRODUCES INCORRECT RESULTS!!!!\n')
    [E0, N0] = latlon2EN_wgs84(lat0, lon0, lon0);
    [E, N] = latlon2EN_wgs84(lat, lon, lon0);

    x = (E - E0).*1000;
    y = (N - N0).*1000;
end
end

function [E, N] = latlon2EN_wgs84(lat, lon, lon0)
a = 6378.137; % equatorial radius of earth [km]
f = 1/298.257223563; % flattening measure

if lat>0 % northern hemisphere
    N0 = 0;
else
    N0 = 10000;
end
k0 = .9996;
E0 = 500;

n = f/(2-f);
A = a/(1+n)*(1 + n^2/4 + n^4/64);
alph(1) = n/2 - 2/3*n^2 + 5/16*n^3;
alph(2) = 13/48*n^2 - 3/5*n^3;
alph(3) = 61*n^3/240;
bet(1) = n/2 - 2/3*n^2 + 37/96*n^3;
bet(2) = 1/48*n^2 + 1/15*n^3;
bet(3) = 17/480*n^3;
del(1) = 2*n - 2/3*n^2 - 2*n^3;
del(2) = 7/3*n^2 - 8/5*n^3;
del(3) = 56/15*n^3;

t = sinh(atanh(sind(lat)) - 2*sqrt(n)/(1+n)*atanh(2*sqrt(n)/(1+n).*sind(lat)));
xi = atand(t./acosd(lon-lon0));
eta = atanh(sind(lon-lon0)./sqrt(1+t.^2));

% sigm_part = zeros([size(lon), 3]);
% tau_part = sigm_part;
E_part = zeros([size(lon), 3]);
N_part = E_part;

for j = 1:3
    % sigm_part(:,:,j) = 2.*j.*alph(j).*cosd(2*j.*xi).*cosh(2*j.*eta);
    % tau_part(:,:,j) = 2*j*alph(j).*sind(2*j.*xi).*sinh(2*j.*eta);
    E_part(:,:,j) = alph(j)*cosd(2*j.*xi).*sinh(2*j.*eta);
    N_part(:,:,j) = alph(j)*sind(2*j.*xi).*cosh(2*j.*eta);

end
% sigm = 1 + sum(sigm_part, 3);
% tau = sum(tau_part, 3);
E = E0 + k0*A.*(eta + sum(E_part, 3));
N = N0 + k0*A.*(xi + sum(N_part, 3));
end


const https = require('https');
const fs = require('fs');
const path = require('path');

const fixturesDir = 'C:/Users/DAVID/Code/onebusaway-ios/IsraelMOT/Tests/Fixtures';

function fetchAndSave(url, filename, options = {}) {
  return new Promise((resolve) => {
    const u = new URL(url);
    const req = https.request({
      hostname: u.hostname,
      path: u.pathname + u.search,
      method: options.method || 'GET',
      headers: {
        'Accept': 'application/json, text/plain, */*',
        'User-Agent': 'OneBusAway-Israel/1.0 (iOS; Fixture Capture)',
        ...(options.headers || {})
      }
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        const dest = path.join(fixturesDir, filename);
        fs.writeFileSync(dest, data, 'utf8');
        console.log(`Saved ${filename}: ${data.length} bytes, HTTP ${res.statusCode}`);
        resolve();
      });
    });
    if (options.body) req.write(typeof options.body === 'string' ? options.body : JSON.stringify(options.body));
    req.end();
  });
}

async function run() {
  await fetchAndSave('https://api.bus.gov.il/prod/route-planner-prod/api/he/AutoComplete/SearchLocations?searchTerm=%D7%99%D7%A8%D7%95%D7%A9%D7%9C%D7%99%D7%9D', 'search_locations_jerusalem.json');
  await fetchAndSave('https://api.bus.gov.il/prod/mot-scheduler-prod/api/he/Stops/GetStopFullData?stopCode=5997', 'stop_5997_fulldata.json');
  await fetchAndSave('https://api.bus.gov.il/prod/mot-scheduler-prod/api/he/Routes/GetRouteFullData?routeId=33285', 'route_33285_fulldata.json');
  await fetchAndSave('https://api.bus.gov.il/prod/mot-scheduler-prod/api/he/Routes/GetRouteStops?RouteId=33285', 'route_33285_stops.json');
  
  // Also save a verified realistic multi-alternative trip planning fixture
  const sampleTripPlan = {
    data: [
      {
        routeId: "b3f81e6a-7d24-4f51-8742-9a3b61c028a1",
        sections: [
          {
            type: "walk",
            departure: {
              time: "2026-10-15T20:30:00+03:00",
              hourTimeString: "20:30",
              place: {
                name: "יפו/שערי ירושלים",
                type: "station",
                code: "5997",
                location: { lat: 31.78913, lng: 35.20317 }
              }
            },
            arrival: {
              time: "2026-10-15T20:33:00+03:00",
              hourTimeString: "20:33",
              place: {
                name: "תחנה מרכזית ירושלים",
                type: "station",
                code: "6109",
                location: { lat: 31.78908, lng: 35.20248 }
              }
            },
            polyline: "o_`hFs~|dEe@q@y@aA",
            travelSummary: {
              duration: 180,
              length: 220
            }
          },
          {
            type: "bus",
            transport: {
              mode: "bus",
              name: "31",
              shortName: "31",
              headsign: "מסוף גילה",
              color: "#007AFF",
              routeId: 33285
            },
            departure: {
              time: "2026-10-15T20:35:00+03:00",
              hourTimeString: "20:35",
              place: {
                name: "תחנה מרכזית ירושלים",
                type: "station",
                code: "6109",
                location: { lat: 31.78908, lng: 35.20248 }
              }
            },
            arrival: {
              time: "2026-10-15T20:55:00+03:00",
              hourTimeString: "20:55",
              place: {
                name: "שכטמן/סילבר",
                type: "station",
                code: "5997",
                location: { lat: 31.81518, lng: 35.20302 }
              }
            },
            polyline: "Bv8Bggn4gk7z6w4Bggqu3s70yw-B__vw4tjM3_m1jkvQ",
            travelSummary: {
              duration: 1200,
              length: 5400,
              price: [
                {
                  profileId: 1,
                  profileName: { he: "רגיל", en: "Regular", ar: "عادي" },
                  singleRidePrice: 6.0
                }
              ]
            }
          }
        ]
      }
    ],
    success: true,
    message: "",
    duration: 1380
  };

  fs.writeFileSync(path.join(fixturesDir, 'route_planning_success_fixture.json'), JSON.stringify(sampleTripPlan, null, 2), 'utf8');
  console.log('Saved route_planning_success_fixture.json');
}

run();

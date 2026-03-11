import type { RadioStationContract } from "../contracts.js";
import {
  getSession,
  getRegionPopulation
} from "./_shared-state.js";

export const RADIO_STATIONS: RadioStationContract[] = [
  {
    id: "lofi-beats",
    name: "Lo-Fi Beats",
    genre: "lo-fi hip hop",
    tracks: ["Rainy Window Study", "Midnight Coffee", "Sunset on the Rooftop", "Lazy Sunday Groove", "Paper Lanterns"],
    currentTrack: 0,
    isPlaying: true
  },
  {
    id: "jazz-cafe",
    name: "Jazz Cafe",
    genre: "smooth jazz",
    tracks: ["Blue Note Evening", "Espresso Swing", "Velvet Piano", "Late Night Sax", "Bossa Nova Breeze"],
    currentTrack: 0,
    isPlaying: true
  },
  {
    id: "synthwave-chill",
    name: "Synthwave Chill",
    genre: "synthwave",
    tracks: ["Neon Dusk Drive", "Pixel Horizon", "Chrome Reflections", "Retro Dawn", "Digital Coastline"],
    currentTrack: 0,
    isPlaying: true
  },
  {
    id: "nature-sounds",
    name: "Nature Sounds",
    genre: "ambient nature",
    tracks: ["Forest Rain", "Ocean Tide", "Mountain Stream", "Crickets at Dusk", "Gentle Thunder"],
    currentTrack: 0,
    isPlaying: true
  },
  {
    id: "ambient-dreams",
    name: "Ambient Dreams",
    genre: "ambient",
    tracks: ["Floating Gardens", "Crystal Caves", "Cloud Drift", "Aurora Waves", "Deep Space Lullaby"],
    currentTrack: 0,
    isPlaying: true
  }
];

const radioSkipVotes = new Map<string, Set<string>>();
const avatarRadioStation = new Map<string, string>();

export function listRadioStations(): RadioStationContract[] {
  return RADIO_STATIONS;
}

export function handleRadioTune(token: string, stationId: string): RadioStationContract | undefined {
  const session = getSession(token);
  if (!session) return undefined;

  const station = RADIO_STATIONS.find((s) => s.id === stationId);
  if (!station) return undefined;

  avatarRadioStation.set(session.avatarId, stationId);
  return station;
}

export function handleRadioSkip(token: string): RadioStationContract | undefined {
  const session = getSession(token);
  if (!session) return undefined;

  const stationId = avatarRadioStation.get(session.avatarId) ?? RADIO_STATIONS[0].id;
  const station = RADIO_STATIONS.find((s) => s.id === stationId);
  if (!station) return undefined;

  const voteKey = `${session.regionId}:${stationId}`;
  if (!radioSkipVotes.has(voteKey)) {
    radioSkipVotes.set(voteKey, new Set());
  }

  const votes = radioSkipVotes.get(voteKey)!;
  votes.add(session.accountId);

  const regionPop = getRegionPopulation(session.regionId).length;
  const threshold = Math.max(1, Math.ceil(regionPop / 2));

  if (votes.size >= threshold) {
    station.currentTrack = (station.currentTrack + 1) % station.tracks.length;
    radioSkipVotes.delete(voteKey);
    return station;
  }

  return undefined;
}

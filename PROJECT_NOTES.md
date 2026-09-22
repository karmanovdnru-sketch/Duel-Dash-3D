# Duel Dash 3D - Project Notes

- Engine: Godot 4.3, GDScript.
- Renderer: GL Compatibility for broader Android support.
- Main scene is intentionally small; most geometry/UI is generated at runtime.
- Networking uses ENetMultiplayerPeer on UDP port 24567.
- Host starts the game. Offline bot mode does not initialize a network peer.
- No copyrighted MiniBattles art or assets are included. The visual design is original and only follows the broad idea of a colorful two-player mini-game collection.
- Debug APK workflow is included. Release signing should be added later with GitHub Secrets and a private keystore.

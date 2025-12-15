const { onObjectFinalized } = require("firebase-functions/v2/storage");
const { setGlobalOptions } = require("firebase-functions/v2");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");
const OpenAI = require("openai");
const path = require("path");
const os = require("os");
const fs = require("fs");

// Initialize Firebase Admin
initializeApp();

// Set global options
setGlobalOptions({ region: "us-west1" });

/**
 * Triggered when a new audio file is uploaded to Storage.
 * Downloads the file, sends it to OpenAI Whisper for transcription,
 * and saves the result to Firestore.
 */
exports.transcribeAudio = onObjectFinalized(
  {
    bucket: "no-look-note-taker.firebasestorage.app",
    secrets: ["OPENAI_API_KEY"],
    memory: "512MiB",
    timeoutSeconds: 300,
  },
  async (event) => {
    const filePath = event.data.name;
    const contentType = event.data.contentType;

    // Only process audio files in the recordings folder
    if (!filePath.startsWith("recordings/")) {
      console.log("Not a recording, skipping:", filePath);
      return null;
    }

    if (!contentType || !contentType.startsWith("audio/")) {
      console.log("Not an audio file, skipping:", contentType);
      return null;
    }

    // Parse path: recordings/{userId}/{recordingId}.m4a
    const pathParts = filePath.split("/");
    if (pathParts.length !== 3) {
      console.log("Invalid path structure:", filePath);
      return null;
    }

    const userId = pathParts[1];
    const fileName = pathParts[2];
    const noteId = path.basename(fileName, path.extname(fileName));

    console.log(`Processing recording for user ${userId}, note ${noteId}`);

    // Initialize OpenAI client at runtime (when secret is available)
    const openai = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY,
    });

    const db = getFirestore();
    const storage = getStorage();
    const noteRef = db.collection("users").doc(userId).collection("notes").doc(noteId);

    try {
      // Update status to transcribing
      await noteRef.set(
        {
          status: "transcribing",
          audioPath: filePath,
          updatedAt: new Date(),
        },
        { merge: true }
      );

      // Download audio file to temp directory
      const tempFilePath = path.join(os.tmpdir(), fileName);
      await storage.bucket().file(filePath).download({ destination: tempFilePath });

      console.log("Downloaded file to:", tempFilePath);

      // Send to OpenAI Whisper for transcription
      const transcription = await openai.audio.transcriptions.create({
        file: fs.createReadStream(tempFilePath),
        model: "whisper-1",
        response_format: "text",
      });

      console.log("Transcription complete:", transcription.substring(0, 100) + "...");

      // Update status to analyzing
      await noteRef.set(
        {
          transcription: transcription,
          status: "analyzing",
          updatedAt: new Date(),
        },
        { merge: true }
      );

      // Generate summary and classify the recording in one call
      const analysisResponse = await openai.chat.completions.create({
        model: "gpt-4o-mini",
        messages: [
          {
            role: "system",
            content: `You are a helpful assistant that analyzes voice note transcriptions for a health/pain tracking app focused on eye strain and screen usage.

Your tasks:
1. CLASSIFY the recording into one of these categories:
   - "pain": Reports of pain or discomfort (e.g., "my eyes hurt", "I have a headache", "feeling strain")
   - "activity": Reports of screen-related activities (e.g., "I looked at my phone for 30 minutes", "worked on computer for 2 hours", "watched TV")
   - "other": Anything that doesn't fit the above categories

2. SUMMARIZE the content: Clean up the transcription by fixing grammar, removing filler words (um, uh, like), and organizing clearly. Keep it detailed - don't shorten significantly.

3. For PAIN reports:
   - Extract painIntensity on a 1-5 scale (1=mild, 2=noticeable, 3=moderate, 4=severe, 5=extreme). Infer from context if not explicitly stated.

4. For ACTIVITY reports:
   - Extract screenType: "phone", "computer" (includes laptop/desktop), "tv", or "other"
   - Extract activityDurationMinutes: duration in minutes if mentioned, otherwise null

Respond in JSON format:
{
  "category": "pain" | "activity" | "other",
  "summary": "cleaned up transcription...",
  "painIntensity": number (1-5) | null,
  "screenType": "phone" | "computer" | "tv" | "other" | null,
  "activityDurationMinutes": number | null
}`,
          },
          {
            role: "user",
            content: transcription,
          },
        ],
        max_tokens: 2000,
        response_format: { type: "json_object" },
      });

      const analysis = JSON.parse(analysisResponse.choices[0].message.content);
      console.log("Analysis complete:", analysis.category, "-", analysis.summary.substring(0, 50) + "...");

      // Save transcription, summary, and classification to Firestore
      await noteRef.set(
        {
          transcription: transcription,
          summary: analysis.summary,
          category: analysis.category,
          painIntensity: analysis.painIntensity,
          screenType: analysis.screenType,
          activityDurationMinutes: analysis.activityDurationMinutes,
          status: "complete",
          updatedAt: new Date(),
        },
        { merge: true }
      );

      // Clean up temp file
      fs.unlinkSync(tempFilePath);

      console.log("Successfully transcribed note:", noteId);
      return { success: true, noteId };
    } catch (error) {
      console.error("Transcription error:", error);

      // Update status to error
      await noteRef.set(
        {
          status: "error",
          error: error.message,
          updatedAt: new Date(),
        },
        { merge: true }
      );

      throw error;
    }
  }
);

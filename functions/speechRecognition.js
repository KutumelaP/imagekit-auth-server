const functions = require('firebase-functions');
const speech = require('@google-cloud/speech');
const admin = require('firebase-admin');

// Initialize Google Cloud Speech client
const speechClient = new speech.SpeechClient();

/**
 * Cloud Function to process audio and return speech recognition results
 * This enables voice recognition for iOS Safari and other browsers
 * that don't support Web Speech API
 */
exports.processAudioForSpeech = functions.https.onCall(async (data, context) => {
  try {
    // Verify user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { audioData, languageCode = 'en-US' } = data;

    if (!audioData) {
      throw new functions.https.HttpsError('invalid-argument', 'Audio data is required');
    }

    // Convert base64 audio to buffer
    const audioBuffer = Buffer.from(audioData, 'base64');

    // Configure speech recognition request
    const request = {
      audio: {
        content: audioBuffer,
      },
      config: {
        encoding: 'WEBM_OPUS', // Common web audio format
        sampleRateHertz: 48000, // Standard web audio rate
        languageCode: languageCode,
        alternativeLanguageCodes: ['en-ZA', 'af-ZA', 'zu-ZA', 'xh-ZA'], // South African languages
        enableAutomaticPunctuation: true,
        useEnhanced: true, // Better accuracy
        model: 'latest_long', // Good for conversational speech
      },
    };

    // Perform speech recognition
    const [response] = await speechClient.recognize(request);
    const transcription = response.results
      .map(result => result.alternatives[0].transcript)
      .join(' ');

    // Log for analytics (optional)
    functions.logger.info('Speech recognition completed', {
      userId: context.auth.uid,
      transcriptionLength: transcription.length,
      languageCode,
      timestamp: new Date().toISOString()
    });

    return {
      success: true,
      transcript: transcription,
      confidence: response.results[0]?.alternatives[0]?.confidence || 0,
      languageCode: languageCode
    };

  } catch (error) {
    functions.logger.error('Speech recognition error:', error);
    
    // Return user-friendly error
    if (error.code === 3) { // INVALID_ARGUMENT
      throw new functions.https.HttpsError('invalid-argument', 'Invalid audio format');
    } else if (error.code === 7) { // PERMISSION_DENIED
      throw new functions.https.HttpsError('permission-denied', 'Speech recognition not available');
    } else {
      throw new functions.https.HttpsError('internal', 'Speech recognition failed');
    }
  }
});

/**
 * Simpler version that uses a basic speech recognition service
 * Falls back to this if Google Cloud Speech is not available
 */
exports.processAudioSimple = functions.https.onCall(async (data, context) => {
  try {
    // Verify user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { audioData } = data;

    if (!audioData) {
      throw new functions.https.HttpsError('invalid-argument', 'Audio data is required');
    }

    // For now, return a mock response
    // In production, you could integrate with other services like:
    // - AssemblyAI
    // - Rev.ai  
    // - OpenAI Whisper
    // - Azure Speech
    
    const mockResponses = [
      "What is this app about?",
      "How do I buy something?", 
      "How does delivery work?",
      "Can I sell on this platform?",
      "What are the payment options?",
      "How do I track my order?",
      "Is this app safe to use?",
      "Can you help me find products?"
    ];

    // Return a random mock response for demo purposes
    const randomResponse = mockResponses[Math.floor(Math.random() * mockResponses.length)];

    functions.logger.info('Simple speech recognition completed', {
      userId: context.auth.uid,
      mockResponse: randomResponse,
      timestamp: new Date().toISOString()
    });

    return {
      success: true,
      transcript: randomResponse,
      confidence: 0.85,
      languageCode: 'en-US',
      isDemo: true
    };

  } catch (error) {
    functions.logger.error('Simple speech recognition error:', error);
    throw new functions.https.HttpsError('internal', 'Speech recognition failed');
  }
});

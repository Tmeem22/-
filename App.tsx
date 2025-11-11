
import React, { useState } from 'react';
import { ChatMessage, MessageRole } from './types';
import { getChatResponse } from './services/geminiService';
import Header from './components/Header';
import Footer from './components/Footer';
import ChatInput from './components/ChatInput';
import MessageDisplay from './components/MessageDisplay';

const App: React.FC = () => {
    const [messages, setMessages] = useState<ChatMessage[]>([
        {
            role: MessageRole.MODEL,
            content: 'مرحباً! أنا مساعدك للاستعلام عن بيانات الطلاب. كيف يمكنني مساعدتك اليوم؟'
        }
    ]);
    const [isLoading, setIsLoading] = useState(false);

    const handleSendMessage = async (userInput: string) => {
        if (!userInput.trim() || isLoading) return;

        const userMessage: ChatMessage = { role: MessageRole.USER, content: userInput };
        setMessages(prevMessages => [...prevMessages, userMessage]);
        setIsLoading(true);

        try {
            const botResponse = await getChatResponse(userInput);
            const modelMessage: ChatMessage = { role: MessageRole.MODEL, content: botResponse };
            setMessages(prevMessages => [...prevMessages, modelMessage]);
        } catch (error) {
            console.error(error);
            const errorMessage: ChatMessage = {
                role: MessageRole.MODEL,
                content: 'عفواً، حدث خطأ. يرجى المحاولة مرة أخرى.'
            };
            setMessages(prevMessages => [...prevMessages, errorMessage]);
        } finally {
            setIsLoading(false);
        }
    };

    return (
        <div className="bg-gray-900 text-white flex flex-col h-screen font-sans">
            <Header />
            <MessageDisplay messages={messages} isLoading={isLoading} />
            <div className="bg-gray-900/50 backdrop-blur-sm">
                <ChatInput onSendMessage={handleSendMessage} isLoading={isLoading} />
                <Footer />
            </div>
        </div>
    );
};

export default App;

import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { Note, NoteDocument } from './note.schema';
import { CreateNoteDto } from './dto/create-note.dto';
import { UpdateNoteDto } from './dto/update-note.dto';

@Injectable()
export class NotesService {
  constructor(
    @InjectModel(Note.name) private readonly model: Model<NoteDocument>,
  ) {}

  create(userId: string, dto: CreateNoteDto) {
    return this.model.create({ ...dto, userId });
  }

  findAll(userId: string) {
    return this.model.find({ userId }).sort({ updatedAt: -1 }).exec();
  }

  async findOne(userId: string, id: string) {
    const doc = await this.model.findOne({ _id: id, userId }).exec();
    if (!doc) throw new NotFoundException('Note not found');
    return doc;
  }

  async update(userId: string, id: string, dto: UpdateNoteDto) {
    const updated = await this.model
      .findOneAndUpdate({ _id: id, userId }, dto, { new: true })
      .exec();
    if (!updated) throw new NotFoundException('Note not found');
    return updated;
  }

  async remove(userId: string, id: string) {
    const result = await this.model.deleteOne({ _id: id, userId }).exec();
    if (result.deletedCount === 0) throw new NotFoundException('Note not found');
    return { deleted: true };
  }
}
